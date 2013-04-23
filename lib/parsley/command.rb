require 'open3'
require 'shellwords'

class Parsley
  class Command
    def run(command, *args)
      idx = 0
      escaped_command = command.gsub('?') do |match|
        Shellwords.escape(args[idx].to_s).tap do
          idx += 1
        end
      end

      output, exit_status = Open3.capture2e(escaped_command)

      raise CommandFailed, "#{escaped_command}:\n#{output}" if exit_status.to_i != 0
      output
    end
  end

  class CommandFailed < StandardError; end
end
