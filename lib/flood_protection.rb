module JsChat
  module Errors
    class Flooding < JsChat::Error ; end
    class StillFlooding < Exception ; end
  end

  module FloodProtection 
    def seen!
      @activity_log ||= []
      @activity_log << Time.now.utc
      @activity_log.shift if @activity_log.size > 50
      remove_old_activity_logs
      detect_flooding

      if flooding?
        if @still_flooding
          raise JsChat::Errors::StillFlooding
        else
          @still_flooding = true
          raise JsChat::Errors::Flooding.new('Please wait a few seconds before responding')
        end
      elsif @still_flooding
        @still_flooding = false
      end
    end

    def detect_flooding
      @flooding = @activity_log.size > 10 and @activity_log.sort.inject { |i, sum| sum.to_i - i.to_i } - @activity_log.first.to_i < 0.5
    end

    def flooding?
      @flooding
    end

    def remove_old_activity_logs
      @activity_log.delete_if { |l| l + 5 < Time.now.utc }
    end
  end
end
