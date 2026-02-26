require 'sinatra'
require 'net/http'
require 'json'
require 'base64'

# 設定 API KEY
GEMINI_API_KEY = ENV['GEMINI_API_KEY']

helpers do
  def h(text)
    Rack::Utils.escape_html(text)
  end
end

def ask_gemini(text_input, file_data = nil, mime_type = nil)
  # 使用最標準的 v1beta 網址
  uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=#{GEMINI_API_KEY}")
  
  prompt = "你是一位精通台灣勞基法與護理法規的律師。請針對以下內容鑑定是否違法，並給予具體建議："
  
  parts = [{ text: "#{prompt}\n#{text_input}" }]
  if file_data && mime_type
    parts << { inline_data: { mime_type: mime_type, data: file_data } }
  end

  payload = { contents: [{ parts: parts }] }.to_json
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri.request_uri, { 'Content-Type' => 'application/json' })
  request.body = payload
  
  response = http.request(request)
  res_body = JSON.parse(response.body)
  
  if res_body['candidates'] && res_body['candidates'][0]['content']
    res_body['candidates'][0]['content']['parts'][0]['text']
  else
    "⚠️ 鑑定失敗。API 回報：#{res_body.dig('error', 'message') || '請檢查 API KEY 設定'}"
  end
rescue => e
  "❌ 發生錯誤：#{e.message}"
end

get '/' do
  erb :index
end

post '/analyze' do
  user_text = params[:user_input] || ""
  file = params[:attachment]
  
  file_base64 = nil
  mime_type = nil

  if file && file[:tempfile]
    file_base64 = Base64.strict_encode64(file[:tempfile].read)
    mime_type = file[:type]
  end

  @result = ask_gemini(user_text, file_base64, mime_type)
  erb :result
end

__END__

@@index
<!DOCTYPE html>
<html>
<head>
  <title>護理勞權 AI 律師</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { font-family: sans-serif; background: #f0f4f8; padding: 20px; display: flex; justify-content: center; min-height: 100vh; }
    .card { background: white; width: 100%; max-width: 500px; padding: 25px; border-radius: 15px; box-shadow: 0 5px 15px rgba(0,0,0,0.1); height: fit-content; }
    textarea { width: 100%; height: 100px; padding: 10px; border: 1px solid #ddd; border-radius: 8px; box-sizing: border-box; }
    .upload { margin: 15px 0; border: 1px dashed #ccc; padding: 10px; border-radius: 8px; }
    button { width: 100%; background: #3182ce; color: white; padding: 12px; border: none; border-radius: 8px; font-size: 1rem; cursor: pointer; }
  </style>
</head>
<body>
  <div class="card">
    <h2>⚖️ 護理勞權 AI 律師</h2>
    <form action="/analyze" method="post" enctype="multipart/form-data">
      <textarea name="user_input" placeholder="請輸入文字..."></textarea>
      <div class="upload">
        <label style="font-size: 0.9rem;">📤 上傳截圖或錄音：</label>
        <input type="file" name="attachment" accept="image/*