require 'openbase'

module Sequel
  module OpenBase
    class Database < Sequel::Database
      set_adapter_scheme :openbase
      
      def connect
        OpenBase.new(
          opts[:database],
          opts[:host] || 'localhost',
          opts[:user],
          opts[:password]
        )
      end
      
      def disconnect
        # would this work?
        @pool.disconnect {|c| c.disconnect}
      end
    
      def dataset(opts = nil)
        OpenBase::Dataset.new(self, opts)
      end
    
      def execute(sql)
        log_info(sql)
        @pool.hold {|conn| conn.execute(sql)}
      end
      
      alias_method :do, :execute
    end
    
    class Dataset < Sequel::Dataset
      def literal(v)
        case v
        when Time
          literal(v.iso8601)
        when Date, DateTime
          literal(v.to_s)
        else
          super
        end
      end

      def fetch_rows(sql, &block)
        @db.synchronize do
          result = @db.execute sql
          begin
            @columns = result.column_infos.map {|c| c.name.to_sym}
            result.each do |r|
              row = {}
              r.each_with_index {|v, i| row[@columns[i]] = v}
              yield row
            end
          ensure
            # result.close
          end
        end
        self
      end
      
      def insert(*values)
        @db.do insert_sql(*values)
      end
    
      def update(*args, &block)
        @db.do update_sql(*args, &block)
      end
    
      def delete(opts = nil)
        @db.do delete_sql(opts)
      end
    end
  end
end
