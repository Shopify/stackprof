require 'fileutils'

module StackProf
  class Middleware
    def initialize(app, options = {})
      @app       = app
      @options   = options
      @num_reqs  = options[:save_every] || nil

      Middleware.mode     = options[:mode] || :cpu
      Middleware.interval = options[:interval] || 1000
      Middleware.raw      = options[:raw] || false
      Middleware.enabled  = options[:enabled]
      Middleware.saviour  = options[:saviour]
      Middleware.path     = options[:path] || 'tmp'
      at_exit{ Middleware.save } if options[:save_at_exit]
    end

    def call(env)
      enabled, mode = Middleware.enabled?(env)
      StackProf.start(mode: mode || Middleware.mode, interval: Middleware.interval, raw: Middleware.raw) if enabled
      @app.call(env)
    ensure
      if enabled
        StackProf.stop
        if @num_reqs && (@num_reqs-=1) == 0
          @num_reqs = @options[:save_every]
          Middleware.save(env)
        end
      end
    end

    class << self
      attr_accessor :enabled, :saviour, :mode, :interval, :raw, :path

      def enabled?(env)
        if enabled.respond_to?(:call)
          enabled.call(env)
        else
          enabled
        end
      end

      def save(env = nil, filename = nil)
        if results = StackProf.results
          if saviour.respond_to?(:call)
            saviour.call(env, results)
          else
            FileUtils.mkdir_p(Middleware.path)
            filename ||= "stackprof-#{results[:mode]}-#{Process.pid}-#{Time.now.to_i}.dump"
            File.open(File.join(Middleware.path, filename), 'wb') do |f|
              f.write Marshal.dump(results)
            end
            filename
          end
        end
      end

    end
  end
end
