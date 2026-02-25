require 'sinatra'
require 'net/http'
require 'json'

GEMINI_API_KEY = ENV['GEMINI_API_KEY'] || "AIzaSyAyb8xJevoV9ADxlg1gyNO1wyoSkEHSp50"

# --- 背景邏輯：自動找尋 AI 模型並分析 ---
def ask_lawyer(user_input)
  list_uri = URI("https://generativelanguage.googleapis.com/v1beta/models?key=#{GEMINI_API_KEY}")
  begin
    list_res = Net::HTTP.get(list_uri)
    models_data = JSON.parse(list_res)
    available_model = models_data["models"]&.find { |m| m["supportedGenerationMethods"].include?("generateContent") }
    model_name = available_model ? available_model["name"] : "models/gemini-1.5-flash"

    uri = URI("https://generativelanguage.googleapis.com/v1beta/#{model_name}:generateContent?key=#{GEMINI_API_KEY}")
    prompt = "你是一位精通台灣勞基法與護理人員法規的資深律師。請鑑定這段主管的話：『#{user_input}』。請務必列出具體違反的【法律條文編號】，並給予護理師實戰應對建議。"
    
    payload = { contents: [{ parts: [{ text: prompt }] }] }.to_json
    response = Net::HTTP.post(uri, payload, "Content-Type" => "application/json")
    res = JSON.parse(response.body)
    res.dig("candidates", 0, "content", "parts", 0, "text") || "AI 律師思考中，請稍後..."
  rescue => e
    "❌ 系統錯誤：#{e.message}"
  end
end

# --- 漂亮設計樣式 (CSS) ---
CSS_STYLE = "
<style>
  body { font-family: 'PingFang TC', sans-serif; background-color: #f0f7ff; color: #2d3436; margin: 0; padding: 20px; }
  .container { max-width: 650px; margin: 50px auto; background: white; padding: 40px; border-radius: 24px; box-shadow: 0 15px 35px rgba(0,0,0,0.1); }
  h1 { color: #007aff; text-align: center; font-size: 28px; }
  textarea { width: 100%; height: 160px; border: 2px solid #e1e8ed; border-radius: 16px; padding: 15px; font-size: 16px; box-sizing: border-box; margin-top: 20px; }
  button { width: 100%; background: #007aff; color: white; padding: 16px; border: none; border-radius: 16px; font-size: 18px; font-weight: bold; cursor: pointer; margin-top: 20px; }
  .report { background: #f8faff; border-left: 6px solid #007aff; padding: 25px; border-radius: 12px; line-height: 1.8; margin-top: 20px; font-size: 17px; }
  .back-link { display: block; text-align: center; margin-top: 30px; color: #007aff; text-decoration: none; font-weight: bold; }
</style>
"

# --- 網頁路由 ---
get '/' do
  "#{CSS_STYLE}
  <div class='container'>
    <h1>⚖️ 護理勞權 AI 律師</h1>
    <p style='text-align:center; color:#636e72;'>讓專業法律成為你最強大的後盾</p>
    <form action='/analyze' method='post'>
      <textarea name='speech' placeholder='請貼上主管布達的話，例如：明天病人少改休負時數...' required></textarea>
      <button type='submit'>開始法律鑑定</button>
    </form>
  </div>"
end

post '/analyze' do
  result = ask_lawyer(params[:speech])
  "#{CSS_STYLE}
  <div class='container'>
    <h1>📋 鑑定報告</h1>
    <div class='report'>
      #{result.gsub("\n", "<br>")}
    </div>
    <a href='/' class='back-link'>← 返回重新鑑定</a>
  </div>"
end