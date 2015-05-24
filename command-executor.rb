# -*- mode:ruby -*-

require 'trie'

Struct::new('Thunk', :name, :command, :argument, :help)

class CommandExecutorError < StandardError; end

class CommandExecutor

  def initialize
    @commands = Trie.new
  end

  def add name, command, argument, help
    @commands[name] = Struct::Thunk::new(name, command, argument, help)
  end

  def execute input
    command, argument = input.strip.split(/\s+/, 2)

    # special case:

    return if not command

    completions = @commands.completions(command)

    case completions.count
    when 0
      raise CommandExecutorError, "This program doesn't know how to '#{command}'."
      return

    when 1
      name   = completions[0]
      record = @commands[name]

      thunk    = record.command
      argtype  = record.argument

      error_text = argument_errors(name, argument, argtype)

      raise CommandExecutorError, error_text if error_text

      return thunk.call()              if argtype == nil
      return thunk.call(argument.to_i) if argtype == Fixnum
      return thunk.call(argument.to_s) if argtype == String

      raise CommandExecutorError, "Don't know what to do... for arguments of class '#{argtype}'"
    else
      raise CommandExecutorError, "The '#{input}' command is ambiguous (could be '#{completions.join("', '")}')."
    end
  end

  private

  def argument_errors name, argval, argtype

    return case
           when (not argval.nil? and argtype.nil? )
             "The '#{name}' command requires no parameters."
           when ((argval !~ /^-?+\d+$/ and argtype == Fixnum) or (argval.nil? and argtype == Fixnum))
             "The '#{name}' command requires a number parameter."
           when (argval.nil? and argtype == String)
             "The '#{name}' command requires a string parameter."
           else
             nil
           end
  end

  public

  def usage
    usage_notes = []

    # collect the usage text we'll return

    @commands.values.each do |val|
      usage = val.name               if val.argument == nil
      usage = val.name + " <num>"    if val.argument == Fixnum
      usage = val.name + " <string>" if val.argument == String

      usage_notes.push( { :signature => usage, :help => val.help } )
    end

    max = usage_notes.map { |rec| rec[:signature].length }.max

    texts = []
    usage_notes.each { |rec| texts.push sprintf("%#{max + 1}s:  %s\n", rec[:signature], rec[:help]) }

    return texts
  end

end