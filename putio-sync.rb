require 'cgi'
require 'fileutils'
require 'net/http'
require 'openssl'
require 'ostruct'
require 'pp'
require 'uri'
require 'yaml'

unless open(__FILE__).flock(File::LOCK_EX | File::LOCK_NB)
  puts "script already running..."
  exit
end

# https://api.put.io/v2/docs/
class PutIO
  ROOT = "https://api.put.io/v2/"
  attr_reader :token, :endpoint, :http
  def initialize(token, endpoint=ROOT)
    @token, @endpoint = token, URI(endpoint)
    @http = Net::HTTP.new(@endpoint.host, @endpoint.port)
    @http.use_ssl = true
    # Not good ...
    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end

  def get_files(parent_id=nil)
    args = parent_id ? {parent_id: parent_id} : {}
    get('files/list', args)
  end

  def get_download_url(id)
    # Follow redirect plz
    url = to_url("files/#{id}/download")
    url.query = URI.encode_www_form to_args()
    url
  end

  protected

  def get(path, args={})
    url = to_url(path)
    url.query = URI.encode_www_form to_args(args)
    req = Net::HTTP::Get.new(url.request_uri)
    puts "GET #{url}"
    as_json http.request(req)
  end

  def post(path, args={})
    url = to_url(path)
    args = to_args(args)
    puts "POST #{url} -- #{args.inspect}"
    req = Net::HTTP::Post.new("/users")
    req.set_form_data(args)
    as_json http.request(req)
  end

  def to_url(path)
    url = endpoint.dup
    url.path += path
    url
  end

  def to_args(args={})
    ret = {}
    args.each_pair do |k,v|
      ret[k.to_s] = v
    end
    args['oauth_token'] = @token
    args
  end

  def as_json(res)
    raise "woot? #{res.inspect}" unless res.is_a?(Net::HTTPSuccess)
    YAML.load res.body
  end
end

class Fetcher
  attr_reader :root, :cli

  def initialize(root, cli)
    @root, @cli = root, cli
  end

  def run!
    fetch_files()
  end

  protected

  def fetch_files(id=nil, path=@root)
    FileUtils.mkdir_p(path)
    puts "*** Getting files for #{path}"
    files = cli.get_files(id)['files']

    while files.any?
      file = OpenStruct.new files.pop
      if file.content_type == "application/x-directory"
        fetch_files file.id, File.join(path, file.name)
      else
	file_path = File.join(path, file.name)
        if File.exists?(file_path) && File.size(file_path) == file.size
          puts "*** File already downloaded #{file.name}"
        else
	  url = cli.get_download_url file.id
          if ! fetch(url, file_path)
	    raise "Unable to download #{file.name}"
          end
        end
      end
    end
  end

  def fetch(url, path)
    command = [
      'curl', '-L', '--retry', '5', '-S', '-C', '-', '-o', path, url.to_s
    ]
    p command
    system(*command)
  end
end

root = ARGV[0] || File.expand_path('../putio', __FILE__)
token = ARGV[1] || ENV['PUTIO_TOKEN']

x = PutIO.new(token)
Fetcher.new(root, x).run!
