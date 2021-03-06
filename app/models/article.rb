class Article < DataMapper::Base  
  property :title, :string, :nullable => false, :length => 255
  property :content, :text, :nullable => false
  property :created_at, :datetime
  property :published_at, :datetime
  property :user_id, :integer, :nullable => false
  property :permalink, :string, :length => 255
  property :published, :boolean, :default => false
  property :formatter, :string, :default => "default"
  validates_presence_of :title, :key => "uniq_title"
  validates_presence_of :content, :key => "uniq_content"
  validates_presence_of :user_id, :key => "uniq_user_id"
  
  belongs_to :user
  
  # Core filters
  before_save :set_published_permalink
  after_create :set_create_activity
  after_update :set_update_activity
  
  # Event hooks for plugins
  before_create :fire_before_create_event
  before_update :fire_before_update_event
  before_save :fire_before_save_event
  after_create :fire_after_create_event
  after_update :fire_after_update_event
  after_save :fire_after_save_event
  
  ##
  # This sets the published date and permalink when an article is published
  def set_published_permalink
    # Check to see if we are publishing
    if self.is_published?
      # Set the date, only if we haven't already
      self.published_at = Time.now if self.published_at.nil?
      
      # Set the permalink, only if we haven't already
      self.permalink = create_permalink
    end
    true
  end

  def set_create_activity
    a = Activity.new
    a.message = "Article \"#{self.title}\" created"
    a.save
  end

  def set_update_activity
    a = Activity.new
    a.message = "Article \"#{self.title}\" updated"
    a.save
  end

  def fire_before_create_event
    Hooks::Events.before_create_article(self)
  end

  def fire_before_update_event
    Hooks::Events.before_update_article(self)
  end

  def fire_before_save_event
    Hooks::Events.before_save_article(self)
    Hooks::Events.before_publish_article(self) if self.is_published?
  end

  def fire_after_create_event
    Hooks::Events.after_create_article(self)
  end
  
  def fire_after_update_event
    Hooks::Events.after_update_article(self)
  end

  def fire_after_save_event
    Hooks::Events.after_save_article(self)
    Hooks::Events.after_publish_article(self) if self.is_published?
  end

  def is_published?
    # We need this beacuse the values get populated from the params
    self.published == "1"
  end
  
  def create_permalink
    permalink = Configuration.current.permalink_format.gsub(/:year/,self.published_at.year.to_s)
    permalink.gsub!(/:month/,Padding::pad_single_digit(self.published_at.month))
    permalink.gsub!(/:day/,Padding::pad_single_digit(self.published_at.day))
    
    title = self.title.gsub(/\W+/, ' ') # all non-word chars to spaces
    title.strip!            # ohh la la
    title.downcase!         #
    title.gsub!(/\ +/, '-') # spaces to dashes, preferred separator char everywhere
    permalink.gsub!(/:title/,title)
    
    permalink
  end

  class << self
    ##
    # Custom finders

    def find_recent
      self.all(:published => true, :limit => 10, :order => "published_at DESC")
    end

    def find_by_year(year)
      self.all(:published_at.like => "#{year}%", :published => true, :order => "published_at DESC")
    end

    def find_by_year_month(year, month)
      month = Padding::pad_single_digit(month)
      self.all(:published_at.like => "#{year}-#{month}%", :published => true, :order => "published_at DESC")
    end

    def find_by_year_month_day(year, month, day)
      month = Padding::pad_single_digit(month)
      day = Padding::pad_single_digit(day)
      self.all(:published_at.like => "#{year}-#{month}-#{day}%", :published => true, :order => "published_at DESC")
    end

    def find_by_permalink(permalink)
      self.first(:permalink => permalink)
    end

    def get_archive_hash
      counts = self.find_by_sql("SELECT COUNT(*) as count, #{specific_date_function} FROM articles WHERE published_at IS NOT NULL AND published = 1 GROUP BY year, month ORDER BY year DESC, month DESC")
      archives = counts.map do |entry|
        {
          :name => "#{Date::MONTHNAMES[entry.month.to_i]} #{entry.year}",
          :month => entry.month.to_i,
          :year => entry.year.to_i,
          :article_count => entry.count
        }
      end
      archives
    end

    private 
      def specific_date_function
        # This is pretty nasty loading up the db.yml to get at this, but I wasn't able to find the method in merb just yet. Change it!
        if YAML::load(File.read("config/database.yml"))[Merb.environment.to_sym][:adapter] == 'sqlite3'
          "strftime('%Y', published_at) as year, strftime('%m', published_at) as month"
        else
          "extract(year from published_at) as year, extract(month from published_at) as month"
        end
      end
  end
end