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
  
end
