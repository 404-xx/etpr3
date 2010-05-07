class ItemsController < ApplicationController
  layout nil
  #caches_page :show
  before_filter :fetch_item_info, :only => [:show, :preview]
  
  def new
    @item = Item.new
    respond_to do |wants|
      wants.js { render :partial => "new" }
    end
  end

  def show
  end
  
  def preview
  end
  
  private
    def fetch_item_info
      @item = Item.find_by_iid(params[:id])
      if @item.nil?
        record_not_found
      else
        @item.start_query
        record_not_found if @item.result.empty?
      end
    end

    def record_not_found
      render :text => "商品不存在或已过期!", :status => 404
    end

end
