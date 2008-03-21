class Article < DataMapper::Base
  property :title, :string, :nullable => false
  property :content, :string, :nullable => false
  property :created_at, :datetime
  property :published_at, :datetime
  property :user_id, :integer, :nullable => false
  validates_presence_of :title, :content, :user_id
  
  belongs_to :user
  
  def self.find_recent
    self.all(:published_at.not => nil, :limit => 10, :order => 'published_at DESC')
  end
  
end