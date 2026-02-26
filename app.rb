require 'sinatra'
require 'net/http'
require 'json'
require 'base64'

# 讀取 Render 環境變數
GEMINI_API_KEY = ENV['GEMINI_API_KEY']

def ask_gemini(text_input, file_data = nil, mime_type = nil)
  # 修正為正式版 v1 網址，這是目前最穩定的路徑
  uri = URI("https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=#{GEMINI_API_KEY}")
  
  prompt = "你是一位精通台灣勞基法與護理法規的律師。請針對以下文字、截圖或語音內容鑑定是否違法，並給予護理師具體且專業的法律建議："
  
  # 建立標準資料結構
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
  
  # 解析 AI 回傳的文字
  answer = res_body.dig("candidates", 0, "content", "parts", 0, "text")
  
  if answer
    answer
  else
    # 如果還是失敗，秀出更直覺的錯誤訊息
    error_msg = res_body.dig("error", "message") || "AI 暫時無法回應"
    "⚠️ 鑑定失敗。原因：#{error_msg}"
  end
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
    body { font-family: sans-serif; background-color: #f0f4f8; margin: 0; padding: 20px; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
    .card { background: white; width: 100%; max-width: 500px; padding: 30px; border-radius: 16px; box-shadow: 0 10px 25px rgba(0,0,0,0.05); text-align: center; }
    .disclaimer { background-color: #fff5f5; border: 1px solid #feb2b2; padding: 12px; border-radius: 8px; font-size: 0.8rem; color: #c53030; margin-bottom: 20px; text-align: left; line-height: 1.4; }
    textarea { width: 100%; height: 120px; padding: 12px; border: 1px solid #e2e8f0; border-radius: 8px; box-sizing: border-box; font-size: 1rem; resize: none; }
    .upload-area { margin: 20px 0; text-align: left; border: 2px dashed #e2e8f0; padding: 15px; border-radius: 8px; }
    label { font-size: 0.9rem; font-weight: bold; color: #4a5568; display: block; margin-bottom: 8px; }
    button { width: 100%; background-color: #4299e1; color: white; padding: 14px; border: none; border-radius: 8px; font-size: 1.1rem; font-weight: bold; cursor: pointer; }
  </style>
</head>
<body>
  <div class="card">
    <h2>⚖️ 護理勞權 AI 律師</h2>
    <div class="disclaimer">⚠️ <strong>免責聲明：</strong>本工具由 AI 產生，僅供參考。若遇重大爭議請諮詢工會。</div>
    <form action="/analyze" method="post" enctype="multipart/form-data">
      <textarea name="user_input" placeholder="請在此輸入文字，或上傳截圖與錄音..."></textarea>
      <div class="upload-area">
        <label>📤 附件上傳 (截圖或語音)：</label>
        <input type="file" name="attachment" accept="image/*,audio/*">
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
    body { font-family: sans-serif; background-color: #f0f4f8; padding: 20px; line-height: 1.6; color: #2d3748; }
    .container { background: white; max-width: 600px; margin: 0 auto; padding: 30px; border-radius: 16px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); }
    .back-btn { display: inline-block; margin-top: 25px; color: #4299e1; text-decoration: none; font-weight: bold; }
  </style>
</head>
<body>
  <div class="container">
    <h3>🔍 法律鑑定報告：</h3>
    <div><%= @result.to_s.gsub("\n", "<br>") %></div>
    <a href="/" class="back-btn">← 返回重新鑑定</a>
  </div>
</body>
</html>