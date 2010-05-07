class Item
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :iid
  field :url
  field :seller_nickname
  field :title
  field :desc_body
  field :cid, :type => Integer, :default => 0
  field :is_prod, :type => Boolean, :default => true
  
  index :iid, :unique => true#, :background => true

  def to_s
    iid
  end

  def self.find_by_iid(iid)
    criteria.where(:iid => "#{iid}").first
  end
  
  attr_reader :result, :seller, :shop, :properties, :attrs, \
              :property_pids, :property_vids, :property_keys, \
              :sku_price, :sku_map, :prop_imgs, :prop_img_keys

  FIELDS = "iid,detail_url,num_iid,title,nick,type,cid,props," \
         + "input_pids,input_str,pic_path,num,stuff_status,location," \
         + "price,post_fee,express_fee,ems_fee,freight_payer,modified," \
         + "property_alias,sku.sku_id,sku.properties,sku.quantity,sku.price," \
         + "itemimg.url,propimg.propimg_id,propimg.url,propimg.properties,propimg.position"

  def switch_prod_or_sandbox
    if is_prod
      TaobaoFu.switch_to(TaobaoFu::PRODBOX)
    else
      TaobaoFu.switch_to(TaobaoFu::SANDBOX)
    end
  end

  def start_query
    #params = {:fields => FIELDS,:nick => seller_nickname,:iid => iid}
    switch_prod_or_sandbox
    @result = TaobaoFu.get(:method => 'taobao.item.get', \
                           :fields => FIELDS, \
                           :nick   => seller_nickname, \
                           :iid    => iid)
    return @result
    
    unless @result.empty?
      @result = @result["items"][0] if @result
      get_seller_info
      get_shop_info
      query_properties
      apply_properties
      apply_prop_key_alias
      apply_prop_value_alias
      apply_attributes
      apply_input_attributes
      parse_property_keys
      add_name_alias_to_prop_imgs
    end
    @result
  end  
  
  private
  
  def get_seller_info
    @seller = TaobaoFu.get(:method => 'taobao.user.get', \
                           :fields => 'nick, type, seller_credit, consumer_protection', \
                           :nick   => seller_nickname)
    @seller = @seller["users"][0] if @seller
  end

  def get_shop_info
    @shop = TaobaoFu.get(:method => 'taobao.shop.get', \
                         :fields => 'sid', \
                         :nick  => seller_nickname)
    return if @shop["code"]
    @shop = @shop["shops"][0] if @shop
    @shop["click_url"] = "http://shop#{@shop["sid"]}.taobao.com/"  
  end

  # => [{"prop_name"=>"颜色", "pid"=>"1627207", "name"=>"褐色", "vid"=>"132069", "name_alias"=>"褐色"}, {}, ...]
  def query_properties
    @properties = TaobaoFu.get(:method => 'taobao.itempropvalues.get', \
                               :fields => 'pid,prop_name,vid,name,name_alias', \
                               :pvs    => @result["props"], \
                               :cid    => @result["cid"])
    @properties = properties["prop_values"] if @properties
  end

  def apply_properties
    @property_pids, @property_vids = {}, {}
    if @properties
      @properties.each do |prop|
        @property_pids[prop["pid"]] ||= prop["prop_name"]
        @property_vids[prop["vid"]] ||= prop["name_alias"] || prop["name"]
      end
    end
  end

  def apply_prop_key_alias
    props = TaobaoFu.get(:method => 'taobao.itemprops.get', \
                         :fields => 'pid, name', \
                         :cid => @result["cid"])
    if props
      props["item_props"].each do |prop|
        @property_pids[prop["pid"]] = prop["name"]
      end
    end
  end

  def apply_prop_value_alias
    if @result["property_alias"]
      @result["property_alias"].split(";").each do |pair|
        token = pair.split(":")
        @property_vids[token[1]] = token[2]
      end
    end
  end

  def apply_attributes
    if @properties
      @attrs = {}
      @properties.each do |prop|
        (@attrs[@property_pids[prop["pid"]]] ||= []) << @property_vids[prop["vid"]]
      end
    end
  end    

  def apply_input_attributes
    if @result["input_pids"] && @result["input_str"]
      pids = @result["input_pids"].split(",")
      vals = @result["input_str"].split(",")
      vals.each_with_index do |v, i|
        (@attrs[@property_pids[pids[i]]] ||= []) << v
      end
    end
  end

  # get unique property keys mapping from parse the skus array.
  # => {
  #     "1627207" => ["132069", "130164", "107121"], 
  #     "1627778" => ["28314", "28317", "28316", "28315"]
  #    }
  def parse_property_keys
    @property_keys, @sku_map, sku_price_arr = {}, [], []
    if @result["sku"]
      @result["sku"].each do |sku|
        if sku["quantity"] > 0
          keys, val_at = [], {}
          pairs = sku["properties"].split(";")
          pairs.each do |pair|
            k, v = pair.split(":")
            (@property_keys[k] ||= []) << v
            #@sku_property_keys << k unless @sku_property_keys.include?(k)
            keys << k.to_i
            val_at[k] = v
          end
          sku_properties = []
          keys.sort!.each {|key| sku_properties << %Q{#{key}:#{val_at["#{key}"]}}}
          @sku_map << %Q{"#{sku_properties.join(";")}":{"skuId":"#{sku["sku_id"]}","price":"#{sku["price"]}","stock":"#{sku["quantity"]}"}}
          sku_price_arr << sku["price"]
        end
      end
      sku_price_arr.map!{|p| p.to_f}
      min_price = sku_price_arr.min
      max_price = sku_price_arr.max
      @sku_price = min_price == max_price ? "%.2f" % max_price : format("%.2f - %.2f", min_price, max_price)
      @property_keys.each_value{|value| value.uniq!}
    end
  end

  def add_name_alias_to_prop_imgs
    if @result["prop_img"]
      @prop_img_keys = []
      @prop_imgs = {}
      @result["prop_img"].each do |prop_img|
        k, v = prop_img["properties"].split(":")
        prop_img["name_alias"] = @property_vids[v]
        @prop_img_keys << k
        @prop_imgs[v] = prop_img
      end
    end
  end
  
end
