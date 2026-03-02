require 'sinatra'
require 'net/http'
require 'json'
require 'base64'

# 讀取 Render 環境變數中的 API Key
# 💡 提醒：請確保使用 Google Cloud 專案內產生的那組 Key
GEMINI_API_KEY = ENV['GEMINI_API_KEY']

helpers do
  def h(text)
    Rack::Utils.escape_html(text)
  end
end

def ask_gemini(text_input, file_data = nil, mime_type = nil)
  # 🏆 最終對頻網址：v1beta 是目前最穩定支援多模態的路徑
  uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=#{GEMINI_API_KEY}")
  
  prompt = "你是一位精通台灣勞動基準法與護理法規的專業律師。請針對以下文字、截圖或語音鑑定是否違法，並給予護理師具體且專業的建議："
  
  # 構建官方標準 Payload 結構
  contents = {
    parts: [
      { text: "#{prompt}\n#{text_input}" }
    ]
  }
  
  # 如果有上傳檔案，加入 inline_data
  if file_data && mime_type
    contents[:parts] << {
      inline_data: {
        mime_type: mime_type,
        data: file_data
      }
    }
  end

  payload = { contents: [contents] }.to_json
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri.request_uri, { 'Content-Type' => 'application/json' })
  request.body = payload
  
  response = http.request(request)
  res_body = JSON.parse(response.body)
  
  # 診斷與解析回傳內容
  if res_body['candidates'] && res_body['candidates'][0]['content']
    res_body['candidates'][0]['content']['parts'][0]['text']
  else
    error_msg = res_body.dig('error', 'message') || "AI 暫時無法回應"
    "⚠️ 鑑定失敗。原因：#{error_msg}\n(請確認 Google Cloud API 狀態為『已啟用』)"
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
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <title>護理勞權 AI 律師</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { 
      font-family: 'PingFang TC', sans-serif; 
      background: linear-gradient(135deg, #e0eafc 0%, #cfdef3 100%); 
      margin: 0; padding: 20px; display: flex; justify-content: center; align-items: center; min-height: 100vh; 
    }
    .card { 
      background: rgba(255, 255, 255, 0.9); backdrop-filter: blur(10px);
      width: 100%; max-width: 500px; padding: 35px; border-radius: 24px; 
      box-shadow: 0 15px 35px rgba(0,0,0,0.1); border: 1px solid white;
    }
    h2 { color: #2d3748; text-align: center; margin-bottom: 25px; font-weight: 800; }
    .disclaimer { 
      background-color: #fff5f5; border: 1px solid #feb2b2; 
      padding: 12px; border-radius: 10px; font-size: 0.8rem; color: #c53030; margin-bottom: 20px; 
    }
    textarea { 
      width: 100%; height: 130px; padding: 15px; border: 1px solid #e2e8f0; 
      border-radius: 15px; box-sizing: border-box; font-size: 1rem; margin-bottom: 20px;
      resize: none; outline: none; transition: border 0.3s;
    }
    textarea:focus { border-color: #3182ce; box-shadow: 0 0 0 3px rgba(49, 130, 206, 0.1); }
    .upload-box { 
      border: 2px dashed #cbd5e0; padding: 15px; border-radius: 15px; 
      margin-bottom: 25px; background: #fafafa;
    }
    label { display: block; font-weight: bold; margin-bottom: 8px; color: #4a5568; font-size: 0.9rem; }
    button { 
      width: 100%; background: #3182ce; color: white; padding: 16px; 
      border: none; border-radius: 15px; font-size: 1.1rem; font-weight: bold; 
      cursor: pointer; transition: background 0.3s, transform 0.2s;
    }
    button:hover { background: #2c5282; transform: translateY(-2px); }
    button:active { transform: translateY(0); }
  </style>
</head>
<body>
  <div class="card">
    <h2>⚖️ 護理勞權 AI 律師</h2>
    <div class="disclaimer">⚠️ <strong>法律聲明：</strong>鑑定結果由 AI 生成，僅供勞權參考，不具法律拘束力。</div>
    <form action="/analyze" method="post" enctype="multipart/form-data">
      <textarea name="user_input" placeholder="請在此描述發生的狀況（例如：交班延時、強制休假、排班爭議...）"></textarea>
      <div class="upload-box">
        <label>📤 上傳佐證截圖或錄音：</label>
        <input type="file" name="attachment" accept="image/*,audio/*" style="width: 100%; font-size: 0.8rem;">
      </div>
      <button type="submit">開始法律鑑定</button>
    </form>
  </div>
</body>
</html>

@@result
<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <title>鑑定報告</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { font-family: 'PingFang TC', sans-serif; background: #f7fafc; padding: 20px; color: #2d3748; }
    .container { 
      background: white; max-width: 650px; margin: 20px auto; 
      padding: 40px; border-radius: 24px; box-shadow: 0 4px 20px rgba(0,0,0,0.05);
    }
    .report-title { 
      border-left: 5px solid #3182ce; padding-left: 15px; margin-bottom: 30px; color: #2b6cb0; 
    }
    .content { white-space: pre-wrap; line-height: 1.8; font-size: 1.05rem; }
    .back-btn { 
      display: inline-block; margin-top: 30px; color: #3182ce; 
      text-decoration: none; font-weight: bold; border-bottom: 2px solid transparent;
      transition: border 0.3s;
    }
    .back-btn:hover { border-bottom: 2px solid #3182ce; }
  </style>
</head>
<body>
  <div class="container">
    <div class="report-title"><h3>🔍 護理勞權律師 鑑定報告</h3></div>
    <div class="content"><%= @result %></div>
    <a href="/" class="back-btn">← 返回重新鑑定</a>
  </div>
</body>
</html>