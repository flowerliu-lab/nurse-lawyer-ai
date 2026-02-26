require 'sinatra'
require 'net/http'
require 'json'
require 'base64'

# 確保讀取 Render 環境變數
GEMINI_API_KEY = ENV['GEMINI_API_KEY']

def ask_gemini(text_input, file_data = nil, mime_type = nil)
  # 使用正式版 v1 網址，確保連線穩定
  uri = URI("https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=#{GEMINI_API_KEY}")
  
  prompt = "你是一位精通台灣勞基法與護理法規的律師。請針對以下內容鑑定是否違法，並給予護理師具體且專業的法律建議："
  
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
  
  res_body.dig("candidates", 0, "content", "parts", 0, "text") || "⚠️ 鑑定失敗。原因：#{res_body.dig('error', 'message') || 'AI 暫時無法回應'}"
rescue => e
  "❌ 系統連線異常：#{e.message}"
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
    body { 
      font-family: sans-serif; 
      /* 🎨 想換背景圖片請修改下方 url */
      background: linear-gradient(135deg, #e0eafc 0%, #cfdef3 100%); 
      margin: 0; padding: 20px; display: flex; justify-content: center; align-items: center; min-height: 100vh; 
    }
    .card { background: rgba(255, 255, 255, 0.9); backdrop-filter: blur(10px); width: 100%; max-width: 500px; padding: 30px; border-radius: 20px; box-shadow: 0 10px 25px rgba(0,0,0,0.1); text-align: center; }
    .disclaimer { background-color: #fff5f5; border: 1px solid #feb2b2; padding: 12px; border-radius: 8px; font-size: 0.8rem; color: #c53030; margin-bottom: 20px; text-align: left; }
    textarea { width: 100%; height: 120px; padding: 12px; border: 1px solid #e2e8f0; border-radius: 12px; box-sizing: border-box; font-size: 1rem; }
    .upload-area { margin: 20px 0; text-align: left; border: 2px dashed #cbd5e0; padding: 15px; border-radius: 12px; }
    button { width: 100%; background: #4299e1; color: white; padding: 14px; border: none; border-radius: 12px; font-size: 1.1rem; font-weight: bold; cursor: pointer; }
  </style>
</head>
<body>
  <div class="card">
    <h2>⚖️ 護理勞權 AI 律師</h2>
    <div class="disclaimer">⚠️ <strong>免責聲明：</strong>本工具由 AI 產生，僅供參考。若遇重大爭議請諮詢工會。</div>
    <form action="/analyze