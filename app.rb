require 'sinatra'
require 'net/http'
require 'json'
require 'base64'

# 讀取環境變數
GEMINI_API_KEY = ENV['GEMINI_API_KEY']

def ask_gemini(text_input, file_data = nil, mime_type = nil)
  # 🎯 策略：定義三種可能的網址格式，自動嘗試直到通為止
  endpoints = [
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=#{GEMINI_API_KEY}",
    "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=#{GEMINI_API_KEY}",
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=#{GEMINI_API_KEY}"
  ]
  
  prompt = "你是一位精通台灣勞動基準法與護理法規的專業律師。請針對以下內容鑑定並給予建議：\n"
  payload_obj = {
    contents: [{
      parts: [
        { text: "#{prompt}#{text_input}" },
        file_data ? { inline_data: { mime_type: mime_type, data: file_data } } : nil
      ].compact
    }]
  }

  final_response = "⚠️ 嘗試了所有連線路徑皆失敗，請確認 API 金鑰是否與專案匹配。"

  endpoints.each do |url|
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.request_uri, { 'Content-Type' => 'application/json' })
    request.body = payload_obj.to_json
    
    response = http.request(request)
    res_body = JSON.parse(response.body)

    # 如果抓到內容，立刻回傳並結束循環
    text = res_body.dig("candidates", 0, "content", "parts", 0, "text")
    if text
      return text
    else
      final_response = "⚠️ API 錯誤詳情：#{res_body.dig('error', 'message')}"
    end
  end
  
  final_response
rescue => e
  "❌ 系統連線異常：#{e.message}"
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
    body { font-family: sans-serif; background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%); margin: 0; padding: 20px; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
    .card { background: white; width: 100%; max-width: 500px; padding: 30px; border-radius: 20px; box-shadow: 0 10px 25px rgba(0,0,0,0.1); }
    textarea { width: 100%; height: 120px; padding: 12px; border: 1px solid #e2e8f0; border-radius: 12px; box-sizing: border-box; font-size: 1rem; margin-bottom: 15px; }
    .upload-box { border: 2px dashed #cbd5e0; padding: 15px; border-radius: 12px; margin-bottom: 20px; }
    button { width: 100%; background: #3182ce; color: white; padding: 14px; border: none; border-radius: 12px; font-size: 1.1rem; font-weight: bold; cursor: pointer; }
  </style>
</head>
<body>
  <div class="card">
    <h2 style="text-align: center; margin-top: 0;">⚖️ 護理勞權 AI 律師</h2>
    <form action="/analyze" method="post" enctype="multipart/form-data">
      <textarea name="user_input" placeholder="請描述狀況..."></textarea>
      <div class="upload-box">
        <label style="font-weight: bold; font-size: 0.9rem; margin-left: 10px;">📤 上傳證據：</label>
        <input type="file" name="attachment" accept="image/*,audio/*" style="padding: 10px;">
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
    .container { background: white; max-width: 600px; margin: 0 auto; padding: 30px; border-radius: 20px; box-shadow: 0 4px 10px rgba(0,0,0,0.05); }
    .content { white-space: pre-wrap; word-wrap: break-word; }
  </style>
</head>
<body>
  <div class="container">
    <h3>🔍 法律鑑定報告：</h3>
    <div class="content"><%= @result %></div>
    <a href="/" style="display:inline-block; margin-top:20px; color:#3182ce; font-weight:bold; text-decoration:none;">← 返回重新鑑定</a>
  </div>
</body>
</html>