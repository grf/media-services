# -*- mode:ruby -*-

require 'trie'

Struct.new('ThunkRecord', :name, :command, :argument, :help)

class CommandExecutorError < StandardError; end

class CommandExecutor

  def initialize
    @commands = Trie.new
  end

  def add(name, command, argument, help)
    @commands[name] = Struct::ThunkRecord.new(name, command, argument, help)
  end

  def execute(input)
    command, argument = input.strip.split(/\s+/, 2)

    return unless command # special case

    completions = @commands.completions(command)
    count = completions.count
    fail CommandExecutorError, "This program doesn't know how to '#{command}'." if count == 0
    fail CommandExecutorError, "The '#{command}' command is ambiguous (could be '#{completions.join("', '")}')." if count > 1

    name    = completions[0]
    record  = @commands[name]
    thunk   = record.command
    argtype = record.argument

    error_text = argument_errors(name, argument, argtype)

    fail CommandExecutorError, error_text if error_text

    return case
           when argtype == Fixnum then thunk.call(argument.to_i)
           when argtype == String then thunk.call(argument.to_s)
           when argtype.nil?      then thunk.call
           end

    fail CommandExecutorError, "Don't know what to do... for arguments of class '#{argtype}'"
  end

  def [](value)
    return @commands[value]
  end

  private

  def argument_errors(name, argval, argtype)

    return case
           when (! argval.nil? && argtype.nil?)
             "The '#{name}' command requires no parameters."
           when ((argval !~ /^-?+\d+$/ && argtype == Fixnum) || (argval.nil? && argtype == Fixnum))
             "The '#{name}' command requires a number parameter."
           when (argval.nil? && argtype == String)
             "The '#{name}' command requires a string parameter."
           end
  end

  public

  def usage
    usage_notes = []

    # create an array of the usage texts we'll return

    @commands.values.each do |val|
      usage = val.name if val.argument.nil?

      usage = val.name + ' <num>'    if val.argument == Fixnum
      usage = val.name + ' <string>' if val.argument == String

      usage_notes.push(signature: usage, help: val.help)
    end

    max = usage_notes.map { |rec| rec[:signature].length }.max

    texts = []
    usage_notes.each { |rec| texts.push format("%#{max + 1}s:  %s\n", rec[:signature], rec[:help]) }

    return texts.join
  end

end # of class CommandExecutor
