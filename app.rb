require 'sinatra'
require 'net/http'
require 'json'
require 'base64'

# 讀取環境變數
GEMINI_API_KEY = ENV['GEMINI_API_KEY']

def ask_gemini(text_input, file_data = nil, mime_type = nil)
  # 修正重點：使用簡潔的模型呼叫路徑
  uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=#{GEMINI_API_KEY}")
  
  prompt = "你是一位精通台灣勞動基準法與護理法規的專業律師。請針對以下文字、截圖或語音內容進行法律鑑定，指出是否違法並提供具體建議："
  
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
  
  # 直接抓取回傳文字
  if res_body['candidates'] && res_body['candidates'][0]['content']
    res_body['candidates'][0]['content']['parts'][0]['text']
  else
    "⚠️ 鑑定暫時無法完成。錯誤詳情：#{res_body['error']['message'] if res_body['error']}"
  end
rescue => e
  "❌ 系統異常：#{e.message}"
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
    <h2 style="margin-top:0;">⚖️ 護理勞權 AI 律師</h2>
    <div class="disclaimer">⚠️ 免責聲明：本工具由 AI 產生，僅供法律參考。若遇重大爭議請諮詢工會律師。</div>
    <form action="/analyze" method="post" enctype="multipart/form-data">
      <textarea name="user_input" placeholder="請貼上主管的話，或上傳對話截圖..."></textarea>
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