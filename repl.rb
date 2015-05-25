$LOAD_PATH.unshift File.dirname(__FILE__)

require 'command-executor'

class ReplError < StandardError; end

class Repl
  @@debug      = false
  $stdout.sync = true                    # REPL needs immediate flush.   stdout?

  def initialize(command_exectutor, prompt = 'repl> ', goodbye_message = 'Thanks for all the fish!')
    @commands = command_exectutor
    @prompt   = prompt
    @goodbye  = goodbye_message
    fail ReplError, 'The first argument must be a CommandExecutor object' unless @commands.is_a? CommandExecutor
  end

  # Top level REPL (Read-Eval-Print Loop).

  def repl
    loop do
      write(@prompt)
      command = get
      goodbye if command.nil?
      response = execute(command)
      writeln(response.chomp) unless response.nil? || response.empty?
    end
  rescue => e
    exception_message(e)
    retry
  end

  def debug=(val)
    @@debug = val
  end

  # write, writeln, get, execute are provided for subclassing

  # The 'P' in the REPL: write(text, text...) ship out supplied text
  # strings.

  def write(*text)
    $stdout.write text.flatten.join unless text.empty?
  end

  def writeln(*text)
    write text, "\n"  unless text.empty?
  end

  # The 'R' in the REPL: get - reads and cleans up input, exiting if
  # EOF has been reached (^D is entered, normally).  Input is returned
  # otherwise.

  def get
    input = $stdin.gets
    return unless input
    return input.strip
  end

  # The 'E' in the REPL is mostly done by the CommandExecutor object
  # method CommandExecutor#execute(String).

  def execute(command)
    return @commands.execute(command)
  end

  private

  def debug
    @@debug
  end

  def goodbye
    writeln @goodbye
    exit
  end

  def exception_message(exception)
    writeln @commands.usage, "\n", exception.message
    writeln exception.class, "\n", exception.backtrace.join("\n") if debug
  end

end # of class Repl
