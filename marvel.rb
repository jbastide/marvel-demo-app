require 'sinatra'
require 'byebug'
require 'digest'
require 'rest-client'
require 'json'
require 'sinatra/static_assets'

#
# COMIC_ID 104 is an example of a comic with no listed characters.
# COMIC_ID 400 does list a character as defined by the API (X-Men).
# Browse comic IDs in the interactive Marvel API.
#

COMIC_ID = 399 # FYI, features Spider-Man

PUBLIC_KEY = <YOUR_PUBLIC_MARVEL_API_KEY>

#
# WARNING: Keep your private key out of public view!!!
# DON'T commit it to public source control!!!
#

PRIVATE_KEY = <YOUR_PRIVATE_MARVEL_API_KEY>

#
# Single page app.
# One route here, mapping an http verb to a URL.
#

get '/' do
  @title = 'Just One Special Marvel Comic'

  #
  # Create an MD5 hash for authentication.
  # This needs to happen for each API call.
  #

  marvel_auth_params = create_marvel_auth_params()

  comic_resource_string = "comics/#{COMIC_ID}"

  json_comic_api_result = get_api_result(marvel_auth_params, comic_resource_string)

  if json_comic_api_result == nil
    exit "ERROR: Unable to retrieve a comic API result."
  end

  #
  # Make the data useful for us by putting it into hash form and extracting
  # just the pieces we want to display.
  #

  @comic_info = parse_comic_data(json_comic_api_result)

  #
  # Get the list of all the characters in the comic, including their names and associated
  # thumbnail URLs. Not all comics have characters listed. All of the comics
  # I spot checked through the interactive API had either zero or one characters
  # listed, and they categorized groups of characters (aka, the X-Men) the same
  # as single characters (Silver Surfer.)
  #

  character_resource_string = "comics/#{COMIC_ID}/characters"
  begin
    json_character_api_result = get_api_result(marvel_auth_params, character_resource_string)
  rescue
    puts "INFO: Unable to find any character info for the story."
  end

  @character_list = []

  if json_character_api_result
    @character_list = parse_character_data(json_character_api_result)
  end

  erb :index
end


#
# All helper functions below
#


#
# Helper function.
#

def hash_json_result(json_data)
  api_hash = {}

  begin
    api_hash = JSON.parse(json_data)
  rescue
    puts "INFO: Couldn't parse JSON data"
  end

  api_hash
end

#
# Get info about a comic.
#
# Returns a hash.
#
# This makes the first API call.
#

def parse_comic_data(api_result)

  api_hash = hash_json_result(api_result)

  #
  # We're searching by unique comic ID. Thus, we only expect a single result here.
  #

  unless api_hash["data"]["count"] == 1
    exit "ERROR: Retrieved more than a single result with that comic ID!"
  end

  comic_info = {}

  comic_info[:title] = api_hash["data"]["results"][0]["title"]
  comic_info[:description] = api_hash["data"]["results"][0]["description"]
  comic_info[:character_uri] = api_hash["data"]["results"][0]["characters"]["collectionURI"]
  comic_info[:attributionHTML] = api_hash["attributionHTML"]

  return comic_info
end


#
# Let's clean up the character data so we're not passing in all of it to the view.
# This makes the second API call.
#
# Returns an array of character hashes.
#

def parse_character_data(api_result)

  api_hash = hash_json_result(api_result)

  character_list = []

  if api_hash
    api_hash["data"]["results"].each do |result|
      character_list.push({name: result["name"],
                           thumbnail: result["thumbnail"]["path"],
                           img_extension: result["thumbnail"]["extension"]
                          })
    end
  end

  return character_list
end

#
# Helper function for creating authentication params for the API
#

def create_marvel_auth_params()
  timestamp = Time.now()

  md5 = Digest::MD5.new

  digest_string = "#{timestamp}#{PRIVATE_KEY}#{PUBLIC_KEY}"

  marvel_hex_digest = md5.hexdigest digest_string

  return {timestamp: timestamp, digest: marvel_hex_digest}
end

#
# Specify API resource as string.
#
# Returns a JSON object.
#

def get_api_result(auth_params, resource_string)

  #
  # Need this info for every server-side API call.
  #

  timestamp = auth_params[:timestamp]
  public_api_key = PUBLIC_KEY
  md5_hash = auth_params[:digest]

  begin
    api_result = RestClient.get "http://gateway.marvel.com/v1/public/#{resource_string}",
      :params => {ts: timestamp, apikey: PUBLIC_KEY, hash: md5_hash}
  rescue Exception => e
    puts e.message
    puts e.backtrace
    exit "ERROR: No API Data for that resource string: #{resource_string}"
  end
end
