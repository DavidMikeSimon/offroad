module Offroad
  private
  
  # Non-database model representing general information attached to any mirror file
  # Based on the pattern found here: http://stackoverflow.com/questions/315850/rails-model-without-database
  class MirrorInfo < ActiveRecord::Base
    self.abstract_class = true
    
    def self.columns
      @columns ||= []
    end
    
    [
      [:created_at, :datetime],
      [:online_site, :string],
      [:app, :string],
      [:app_mode, :string],
      [:app_version, :string],
      [:operating_system, :string],
      [:generator, :string],
      [:schema_migrations, :string],
      [:initial_file, :boolean]
    ].each do |attr_name, attr_type|
      columns << ActiveRecord::ConnectionAdapters::Column.new(attr_name.to_s, nil, attr_type.to_s, true)
      validates_presence_of attr_name unless attr_type == :boolean
    end
    
    def self.safe_to_load_from_cargo_stream?
      true
    end
    
    def self.new_from_group(group, initial_file = false)
      mode = Offroad::app_online? ? "online" : "offline"
      migration_query = "SELECT version FROM schema_migrations ORDER BY version"
      migrations = Offroad::group_base_model.connection.select_all(migration_query).map{ |r| r["version"] }
      return MirrorInfo.new(
        :created_at => Time.now.to_s,
        :online_site => Offroad::online_url,
        :app => Offroad::app_name,
        :app_mode => mode.titleize,
        :app_version => Offroad::app_version,
        :operating_system => RUBY_PLATFORM,
        :generator => "Offroad " + Offroad::VERSION_MAJOR.to_s + "." + Offroad::VERSION_MINOR.to_s,
        :schema_migrations => migrations.join(","),
        :initial_file => initial_file
      )
    end
    
    def save
      raise DataError.new("Cannot save MirrorInfo records")
    end
  end
end
