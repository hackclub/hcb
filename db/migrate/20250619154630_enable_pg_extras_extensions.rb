class EnablePgExtrasExtensions < ActiveRecord::Migration[7.2]
  def change
    enable_extension "pg_stat_statements"
    enable_extension "pg_buffercache"
    enable_extension "sslinfo"
  end
end
