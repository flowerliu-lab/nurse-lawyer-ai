require 'sinatra'
require 'net/http'
require 'json'
require 'base64'

# 讀取環境變數
GEMINI_API_KEY = ENV['GEMINI_API_KEY']

def ask_gemini(text_input, file_data = nil, mime_type = nil)
  # 🏆 核心修正：使用 v1 正式版網址並簡化路徑
  uri = URI("https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=#{GEMINI_API_KEY}")
  
  prompt = "你是一位精通台灣勞動基準法與護理法規的專業律師。請針對以下文字、截圖或語音內容進行法律鑑定，指出是否違法並提供建議："
  
  # 構建官方標準 Payload 結構
  contents = {
    parts: [{ text: "#{prompt}\n#{text_input}" }]
  }
  
  if file_data && mime_type
    contents[:parts] << {
      inline_data: { mime_type: mime_type, data: file_data }
    }
  end

  payload = { contents: [contents] }.to_json
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri.request_uri, { 'Content-Type' => 'application/json' })
  request.body = payload
  
  response = http.request(request)
  res_body = JSON.parse(response.body)
  
  # 診斷邏輯
  if res_body['candidates'] && res_body['candidates'][0]['content']
    res_body['candidates'][0]['content']['parts'][0]['text']
  elsif res_body['error']
    "⚠️ API 錯誤：#{res_body['error']['message']}\n(提示：請確認 API KEY 是否正確且已啟用 Gemini 1.5)"
  else
    "⚠️ 回傳格式異常，請檢查日誌。"
  end
rescue => e
  "❌ 連線異常：#{e.message}"
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
    body { font-family: sans-serif; background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%); margin: 0; padding: 20px; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
    .card { background: white; width: 100%; max-width: 500px; padding: 30px; border-radius: 20px; box-shadow: 0 10px 25px rgba(0,0,0,0.1); }
    .disclaimer { background-color: #fff5f5; border: 1px solid #feb2b2; padding: 12px; border-radius: 8px; font-size: 0.8rem; color: #c53030; margin-bottom: 20px; }
    textarea { width: 100%; height: 120px; padding: 12px; border: 1px solid #e2e8f0; border-radius: 12px; box-sizing: border-box; font-size: 1rem; margin-bottom: 15px; }
    .upload-box { border: 2px dashed #cbd5e0; padding: 15px; border-radius: 12px; margin-bottom: 20px; text-align: left; background: #fafafa; }
    button { width: 100%; background: #3182ce; color: white; padding: 14px; border: none; border-radius: 12px; font-size: 1.1rem; font-weight: bold; cursor: pointer; }
  </style>
</head>
<body>
  <div class="card">
    <h2 style="text-align: center; margin-top: 0;">⚖️ 護理勞權 AI 律師</h2>
    <div class="disclaimer">⚠️ <strong>免責聲明：</strong>本工具僅供法律參考。若遇重大爭議請諮詢專業人員。</div>
    <form action="/analyze" method="post" enctype="multipart/form-data">
      <textarea name="user_input" placeholder="請描述狀況或上傳截圖..."></textarea>
      <div class="upload-box">
        <label style="font-weight: bold; font-size: 0.9rem; color: #4a5568;">📤 上傳附件 (截圖或錄音)：</label>
        <input type="file" name="attachment" accept="image/*,audio/*" style="margin-top: 10px; width: 100%;">
      </div>
      <button type="submit">開始法律鑑定</button>
    </form>
  </div>
</body>
</html>

@@result
<!DOCTYPE html>
<html>
<head>
  <title>鑑定報告</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { font-family: sans-serif; background: #f7fafc; padding: 20px; line-height: 1.7; color: #2d3748; }
    .container { background: white; max-width: 600px; margin: 20px auto; padding: 30px; border-radius: 20px; box-shadow: 0 4px 10px rgba(0,0,0,0.05); }
    .content { white-space: pre-wrap; word-wrap: break-word; }
    .back { display: inline-block; margin-top: 25px; color: #3182ce; text-decoration: none; font-weight: bold; }
  </style>
</head>
<body>
  <div class="container">
    <h3 style="border-bottom: 2px solid #edf2f7; padding-bottom: 10px; color: #2b6cb0;">🔍 法律鑑定報告：</h3>
    <div class="content"><%= @result %></div>
    <a href="/" class="back">← 返回重新鑑定</a>
  </div>
</body>
</html>