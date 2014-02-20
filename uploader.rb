require 'mongo'
require 'uri'
require 'json'

def mongo
  return @mongo if @mongo

  # configure connection via ENV['MONGODB_URI']
  # bash:
  #  export MONGODB_URI=mongodb://username:password@host:port/dbname
  # heroku:
  #  heroku config:set MONGODB_URI=mongodb://username:password@host:port/dbname
  client = Mongo::MongoClient.new
  @mongo = client.db
end

def pics
  mongo.collection("pics")
end

before do
  content_type = "application/json"
end

def convert_pic_document(doc)
  {
    url:"#{env['rack.url_scheme']}://#{env['HTTP_HOST']}#{env['SCRIPT_NAME']}/raw/pics/#{doc['filename']}",
    posted_at: doc["posted_at"]
  }
end

before do
  content_type = "application/json"
end

get '/' do
  content_type "text/html"
  "<html><form method='POST' action='/pics' enctype='multipart/form-data'><input type='file' name='file'/><input type='submit' /></form></html>"
end

post '/pics' do
  halt 400, { message: "file is required" }.to_json if params[:file].nil?

  file_ext_match = params[:file][:type].match(/^image\/(.+)/)

  if file_ext_match.nil? or file_ext_match.size < 1
    halt 400, { message: "invalid file type" }.to_json
  end

  filename = "#{Time.now.to_i}.#{file_ext_match[1]}"
  File.open("./public/raw/pics/#{filename}", "wb") do |f|
   f.write params[:file][:tempfile].read
  end

  id = pics.insert({ filename: filename, content_type: params[:file][:type], posted_at: Time.now.to_i })

  { message: "succeeded to save picture", id: id }.to_json
end

get '/pics/something' do
  docs = pics.find_one
  halt 404, { message: "not found" }.to_json if docs.nil?
  convert_pic_document(docs).to_json
end

get '/pics/:id' do
  docs = pics.find(_id: BSON::ObjectId(params[:id])).to_a
  halt 404, { message: "not found" }.to_json if docs.none?
  convert_pic_document(docs[0]).to_json
end
