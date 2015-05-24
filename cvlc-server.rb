# -*- ruby-mode -*-

require 'rest-client'
require 'timeout'
require 'uri'

class CvlcServerError < StandardError; end

class CvlcServer

  QUICKLY_TIMEOUT = 1.75                    # How long to wait for a response from the CVLC server
  STATUS_PAUSE    = 0.25                    # Some commands need a little time to set up, or to complete.  This value should be less than 1 sec, ideally less than 300 msec.

  # e.g. "http://user:password@satyagraha.sacred.net:9090/"

  def initialize server_url, music_root
    @music_root = music_root.gsub(/\/+$/, '')

    # TODO: check that music_root exists

    setup(server_url)  # sets up @server_handle, @user, @password
  end

  private

  def setup server_url
    uri = URI.parse server_url
    server_handle = uri.scheme + "://" + uri.host + (uri.port == 80 ? "" : ":#{uri.port}")

    @server_handle = server_handle
    @user          = uri.user
    @password      = uri.password

  rescue => e
    raise "Can't parse server URL '#{server_url}': #{e.class} #{e.message}'"   # we don't use CvlcServerError in this case because we want to fail hard. TODO: wtf?
  end

  def quickly time = QUICKLY_TIMEOUT
    Timeout.timeout(time) do
      yield
    end
  rescue Timeout::Error => e
    raise CvlcServerError, "Timed out after #{time} seconds"
  end

  # remove unuseful junk from a file/directory name

  def cleanup_pathname path
    return path.gsub(@music_root, '').gsub(/file:\/+/, '').gsub(/^\/+/, '')
  end

  # pretty_status(status) - status is a json-derived hash, print it out somewhat pretty

  def pretty_status status
    strings = []
    status.keys.sort.each { |k| strings.push sprintf("%15s: %s", k, status[k].inspect) }
    return strings.join("\n")
  end

  public

  def ping
    get_status
    return true
  rescue
    return false
  end

  private

  # get_status() - returns data about the current cvlc status - can be as complex as:
  #
  # {
  #   "loop": false,
  #   "audiofilters": {
  #     "filter_0": ""
  #   },
  #   "state": "playing",
  #   "equalizer": [
  #
  #   ],
  #   "rate": 1,
  #   "random": false,
  #   "stats": {
  #     "displayedpictures": 0,
  #     "sentbytes": 0,
  #     "readbytes": 3603606,
  #     "demuxcorrupted": 0,
  #     "playedabuffers": 431,
  #     "decodedvideo": 0,
  #     "sendbitrate": 0,
  #     "averagedemuxbitrate": 0,
  #     "lostpictures": 0,
  #     "demuxreadbytes": 3451489,
  #     "readpackets": 343,
  #     "lostabuffers": 0,
  #     "demuxbitrate": 0.085678078234196,
  #     "averageinputbitrate": 0,
  #     "demuxdiscontinuity": 0,
  #     "sentpackets": 0,
  #     "inputbitrate": 0.080183073878288,
  #     "demuxreadpackets": 0,
  #     "decodedaudio": 431
  #   },
  #   "version": "2.1.4 Rincewind",
  #   "time": 40,
  #   "currentplid": 76,
  #   "videoeffects": {
  #     "saturation": 1,
  #     "contrast": 1,
  #     "gamma": 1,
  #     "hue": 0,
  #     "brightness": 1
  #   },
  #   "position": 0.10163500159979,
  #   "volume": 90,
  #   "length": 394,
  #   "audiodelay": 0,
  #   "apiversion": 3,
  #   "subtitledelay": 0,
  #   "repeat": false,
  #   "information": {
  #     "chapters": [
  #
  #     ],
  #     "category": {
  #       "meta": {
  #         "ISRC": "USU2C1000002",
  #         "track_number": "2",
  #         "title": "Escape Artist",
  #         "description": "Visit http://music.zoekeating.com",
  #         "artwork_url": "file:///home/fischer/.cache/vlc/art/artistalbum/Zoe%20Keating/Into%20The%20Trees/art.jpg",
  #         "date": "2010",
  #         "album": "Into The Trees",
  #         "COMMENT": "Visit http://music.zoekeating.com",
  #         "artist": "Zoe Keating",
  #         "filename": "Escape Artist",
  #         "ALBUMARTIST": "Zoe Keating"
  #       },
  #       "Stream 0": {
  #         "Channels": "Stereo",
  #         "Type": "Audio",
  #         "Codec": "FLAC (Free Lossless Audio Codec) (flac)",
  #         "Bits_per_sample": "16",
  #         "Sample_rate": "44100 Hz"
  #       }
  #     },
  #     "titles": [
  #
  #     ],
  #     "title": 0,
  #     "chapter": 0
  #   },
  #   "fullscreen": 0
  # }

  def get_status
    return JSON.parse(do_command('requests/status.json'))
  end

  def do_command command
    command  = [ @server_handle, '/', command ].join
    resource =  RestClient::Resource.new(command, @user, @password)

    response = quickly do
      res = resource.get
      raise CvlcServerError, "Bad response code #{response.code} for command '#{command}'" unless res.code < 300
      res
    end

    return response
  rescue => e
    raise CvlcServerError, "do_command: #{e}\n" + "do_command: Error tyrying to communicate wth the cvlc media service (is it running?)."
  end

  # get_playlist()  interrogates the cvlc web service and returns a list of music on the
  # current playlist;  elements of the list look as so:
  #
  # {
  #   "uri": "file:///data/Music/Zo%C3%AB%20Keating/Into%20the%20Trees/01.%20Forest.flac",
  #   "id": "75",
  #   "type": "leaf",
  #   "duration": 45,
  #   "current": "current",
  #   "ro": "rw",
  #   "name": "Forest"
  # },
  #
  # The empty playlist appears as so (if music were on the playlist, they'd be under node-id 2, in the children array):
  #
  # {
  #   "id": "1",
  #   "type": "node",
  #   "name": "Undefined",
  #   "ro": "rw"
  #   "children": [
  #                  {
  #                    "children": [       ],
  #                    "id": "2",
  #                    "type": "node",
  #                    "name": "Playlist",
  #                    "ro": "ro"
  #                  },
  #
  #                  {
  #                    "children": [       ],
  #                    "id": "3",
  #                    "type": "node",
  #                    "name": "Media Library",
  #                    "ro": "ro"
  #                  }
  #              ],
  # }
  #


  def get_playlist
    playlist = JSON.parse(do_command('requests/playlist.json'))
    inner    = playlist['children'].first
    output   = []

    if inner['name'] =~ /playlist/i and inner['children'].class == Array
      inner['children'].each do |elt|
        next unless elt['type'] == 'leaf'
        next if elt['uri']  == 'vlc://nop'
        output.push elt
      end
    else
      raise CvlcServerError, "Unexpected playlist output: \n" + JSON.pretty_generate(playlist)
    end
    return output
  end

  # id_now_playing(status) examines the status data structure returned
  # by the cvlc service, and returns the id of the song in the playlist
  # currently playing. If nothing is playing, it returns nil.

  def id_now_playing status
    return (status['state'] == 'playing' ? status['currentplid'].to_i.to_s : nil)
  end


  # currently_playing() returns a pretty string indicating the song
  # playing, or, if nothing is playing, the string 'idle'

  def currently_playing
    sleep STATUS_PAUSE
    status = get_status()
    get_playlist().each do |elt|
      if elt['id'].to_s == id_now_playing(status)
        return sprintf("*   %03d -  %s", elt['id'], cleanup_pathname(URI.decode(elt['uri'])))
      end
    end
    return 'idle'
  end

  public

  ## Top level commands

  # do_list() returns the playlist pretty-printed, highlighting the
  # currently playing entry (if one is being played) with an
  # asterisk. Empty return text is possible.

  def do_list
    status = get_status()
    output = []
    get_playlist().each do |elt|
      marker = (elt['id'].to_s == id_now_playing(status) ? '*' : ' ')
      output.push sprintf("%s   %03d -  %s\n", marker, elt['id'], cleanup_pathname(URI.decode(elt['uri'])))
    end
    return output.join
  end

  # do_add(name) - add the
  # name should not include full URI path (TODO: we'll have to make it
  # do so at some point when we make this a class)

  def do_add pathname
    raise CvlcServerError, "No such file or directory '#{pathname}'" unless File.exists? "#{@music_root}/#{pathname}"
    string = URI.encode(pathname.sub(%r{/+$},'')).gsub('&', '%26')
    do_command("requests/status.json?command=in_play&input=file://#{@music_root}/#{string}&option=novideo")
    return currently_playing()
  end

  # do_status() - returns a compact list of the returned json.

  def do_status
    return pretty_status(get_status)
  end

  # do_next() - do next entry on playlist, wraps around

  def do_next
    do_command('requests/status.json?command=pl_next')
    return currently_playing()
  end

  # do_previous() - do previous entry on playlist, wraps around

  def do_previous
    do_command('requests/status.json?command=pl_previous')
    return currently_playing()
  end

  def do_play_id id
    do_command("requests/status.json?command=pl_play&id=#{id.to_i}")
    return currently_playing()
  end

  def do_delete_id id
    do_command("requests/status.json?command=pl_delete&id=#{id.to_i}")
    return currently_playing()
  end

  def do_raw_list
    return JSON.pretty_generate(JSON.parse(do_command('requests/playlist.json')))
  end

  def do_clear_playlist
    do_command('requests/status.json?command=pl_empty')
    return
  end

  def do_toggle_random
    do_command('requests/status.json?command=pl_random')
    return currently_playing()
  end

  def do_toggle_loop
    do_command('requests/status.json?command=pl_loop')
    return
  end

  def do_toggle_repeat
    do_command('requests/status.json?command=pl_repeat')
    return currently_playing()
  end

  def do_seek amount
    if amount =~ %r{^[+-]?\d+\%?$}
      do_command("requests/status.json?command=seek&val=#{URI.encode(amount)}")
    else
      raise CvlcServerError, "Ill-formed seek amount '#{amount}'"
    end
    return
  end

  # the scoping for using this is pretty atrocious, see setup_commands

  def do_help commands
    return commands.usage
  end

  def do_art
    art = do_command('art');
    return art.inspect
  end

  def do_enqueue pathname
    string = URI.encode(pathname.sub(%r{/+$},''))
    do_command("requests/status.json?command=in_enqueue&input=#{@music_root}/#{string}")
    return currently_playing()
  end

  # Doesn't seem to work

  def do_bonjour
    return pretty_status(JSON.parse(do_command('requests/status.json?command=pl_sd&val=bonjour')))
  end

  # TODO: add this to commands....

  def do_raw_command
    return unless command
    return pretty_status(JSON.parse(do_command(command)))
  end

  def do_stop
    do_command('requests/status.json?command=pl_stop')
    return
  end

  def do_force_pause
    do_command('requests/status.json?command=pl_forcepause')
    return
  end

  def do_force_resume
    do_command('requests/status.json?command=pl_forceresume')
    return
  end

  # 100 == 0 for some reason...

  def do_volume num
    raise CvlcServerError, "The 'volume' command requires an integer value between 1 and 300..." if num.to_i > 300
    raise CvlcServerError, "The 'volume' command requires an integer value between 1 and 300..." if num.to_i < 1

    do_command("requests/status.json?command=volume&val=#{num}")
    sleep STATUS_PAUSE
    return pretty_status(get_status())
  end

end