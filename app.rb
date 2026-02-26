require 'sinatra'
require 'net/http'
require 'json'
require 'base64'

GEMINI_API_KEY = ENV['GEMINI_API_KEY']

def ask_gemini(text_input, file_data = nil, mime_type = nil)
  # 🎯 這裡我們直接換成 v1beta，並使用絕對不會錯的模型全名
  uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=#{GEMINI_API_KEY}")
  
  prompt = "你是一位精通台灣勞動基準法與護理法規的專業律師。請鑑定以下內容並提供建議："
  
  payload = {
    contents: [{
      parts: [
        { text: "#{prompt}\n#{text_input}" },
        file_data ? { inline_data: { mime_type: mime_type, data: file_data } } : nil
      ].compact
    }]
  }.to_json
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri.request_uri, { 'Content-Type' => 'application/json' })
  request.body = payload
  
  response = http.request(request)
  res_body = JSON.parse(response.body)
  
  # 🏆 核心邏輯：如果這個路徑回傳找不到模型，嘗試另一條路徑
  if res_body['error'] && res_body['error']['message'].include?("not found")
    # 嘗試 v1 版本
    uri = URI("https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=#{GEMINI_API_KEY}")
    request = Net::HTTP::Post.new(uri.request_uri, { 'Content-Type' => 'application/json' })
    request.body = payload
    response = http.request(request)
    res_body = JSON.parse(response.body)
  end

  res_body.dig("candidates", 0, "content", "parts", 0, "text") || "⚠️ 鑑定失敗。原因：#{res_body.dig('error', 'message') || 'AI 無回應'}"
rescue => e
  "❌ 連線異常：#{e.message}"
end

get '/' do
  erb :index
end

post '/analyze' do
  user_text = params[:user_input] || ""
  file = params[:attachment]
  file_base64 = file ? Base64.strict_encode64(file[:tempfile].read) : nil
  mime_type = file ? file[:type] : nil

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
    body { font-family: sans-serif; background: #f0f4f8; margin: 0; padding: 20px; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
    .card { background: white; width: 100%; max-width: 500px; padding: 30px; border-radius: 20px; box-shadow: 0 10px 25px rgba(0,0,0,0.1); }
    textarea { width: 100%; height: 120px; padding: 12px; border: 1px solid #e2e8f0; border-radius: 12px; box-sizing: border-box; font-size: 1rem; margin-bottom: 15px; }
    .upload-box { border: 2px dashed #cbd5e0; padding: 15px; border-radius: 12px; margin-bottom: 20px; text-align: left; background: #fafafa; }
    button { width: 100%; background: #3182ce; color: white; padding: 14px; border: none; border-radius: 12px; font-size: 1.1rem; font-weight: bold; cursor: pointer; }
  </style>
</head>
<body>
  <div class="card">
    <h2 style="text-align: center; margin-top: 0;">⚖️ 護理勞權 AI 律師</h2>
    <form action="/analyze" method="post" enctype="multipart/form-data">
      <textarea name="user_input" placeholder="請輸入對話文字..."></textarea>
      <div class="upload-box">
        <label style="font-weight: bold; font-size: 0.9rem;">📤 上傳附件 (截圖或錄音)：</label>
        <input type="file" name="attachment" accept="image/*,audio/*" style="margin-top: 10px; width: 100%;">
      </div>
      <button type="submit">開始法律鑑定</button>
    </form>
  </div>
</body>
</html>

@@result
<html>
<head>
  <title>鑑定報告</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { font-family: sans-serif; background: #f7fafc; padding: 20px; line-height: 1.7; }
    .container { background: white; max-width: 600px; margin: 20px auto; padding: 30px; border-radius: 20px; box-shadow: 0 4px 10px rgba(0,0,0,0.05); }
    .content { white-space: pre-wrap; word-wrap: break-word; }
  </style>
</head>
<body>
  <div class="container">
    <h3>🔍 法律鑑定報告：</h3>
    <div class="content"><%= @result %></div>
    <a href="/" style="display:inline-block; margin-top:20px; color:#3182ce; font-weight:bold;">← 返回</a>
  </div>
</body>
</html>