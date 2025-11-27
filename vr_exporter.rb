# vr_exporter.rb
#
# Plugin SketchUp : Export GLB + Upload API Key
# Version simple & stable
# by LMDDC

require "sketchup.rb"
require "tmpdir"
require "net/http"
require "uri"
require "json"
require "fileutils"

module LMDDC
  module VrExporter

    PLUGIN_NAME    = "VR Exporter"
    API_UPLOAD_URL = "http://localhost:8088/upload_glb.php"
    CODE_LENGTH    = 4

    CONFIG_DIR     = File.join(ENV["APPDATA"].to_s, "VRExporter")
    CONFIG_FILE    = File.join(CONFIG_DIR, "config.json")

    # ---------------------------------------------
    # Récupération API Key locale
    # ---------------------------------------------
    def self.get_api_key
      if File.exist?(CONFIG_FILE)
        data = JSON.parse(File.read(CONFIG_FILE)) rescue {}
        return data["api_key"] if data["api_key"]
      end

      key = UI.inputbox(["Entrez votre API Key :"], [""])&.first

      if key.nil? || key.strip.empty?
        UI.messagebox("Aucune API Key fournie.")
        return nil
      end

      FileUtils.mkdir_p(CONFIG_DIR)
      File.write(CONFIG_FILE, JSON.pretty_generate({ api_key: key }))

      key
    end

    # ---------------------------------------------
    # Popup HTML LMDDC
    # ---------------------------------------------
    def self.show_big_message(code)
      html = <<-HTML
        <html>
        <body style="
            font-family:Arial;
            background:#ff7a00;
            color:white;
            padding:30px;
            text-align:center;">
            
            <img src="https://www.lmddc.lu/images/logo_lmddc_white.svg"
                 width="180" style="margin-bottom:15px;" />

            <h2 style="font-size:12px;">Voici le code à ouvrir dans la VR :</h2>

            <div style="font-size:72px; font-weight:bold; margin:10px 0;">#{code}</div>

            <div style="font-size:12px; opacity:0.9;">Made with love by LMDDC ❤️</div>

            <button onclick="window.close()"
              style="
                margin-top:5px;
                padding:12px 5px;
                font-size:20px;
                background:white;
                color:#ff7a00;
                border:none;
                border-radius:6px;
                cursor:pointer;">
              Fermer
            </button>

        </body>
        </html>
      HTML

      dialog = UI::HtmlDialog.new(
        dialog_title: "Code VR",
        width: 430,
        height: 600,
        resizable: false
      )
      dialog.set_html(html)
      dialog.show
    end

    # ---------------------------------------------
    # Export + Upload
    # ---------------------------------------------
    def self.export_and_upload
      model = Sketchup.active_model
      return UI.messagebox("Aucun modèle actif.") unless model

      api_key = get_api_key
      return unless api_key

      code = generate_code(CODE_LENGTH)

      tmp = Dir.mktmpdir("vr_exporter")
      glb_path = File.join(tmp, "scene_#{code}.glb")

      exported = model.export(glb_path, triangulated_faces: true, texture_maps: true)
      unless exported && File.exist?(glb_path)
        UI.messagebox("Échec export GLB.")
        return
      end

      response = upload_glb(glb_path, code, api_key)

      if response.is_a?(Net::HTTPSuccess)
        begin
          data = JSON.parse(response.body)
          display_code = data.dig("data", "code") || code

          show_big_message(display_code)
          copy_to_clipboard_safe(display_code)

        rescue => e
          UI.messagebox("Upload OK mais JSON invalide : #{e.message}")
        end
      else
        UI.messagebox("Erreur upload : #{response.code}\n#{response.body}")
      end

    ensure
      if tmp && Dir.exist?(tmp)
        Dir.foreach(tmp) do |f|
          next if f == "." || f == ".."
          File.delete(File.join(tmp, f)) rescue nil
        end
        Dir.rmdir(tmp) rescue nil
      end
    end

    # ---------------------------------------------
    # Upload via API Key simple
    # ---------------------------------------------
    def self.upload_glb(file_path, code, api_key)
      uri = URI.parse(API_UPLOAD_URL)

      request = Net::HTTP::Post.new(uri)
      request["X-API-KEY"] = api_key

      form = [
        ["code", code],
        ["file", File.open(file_path)]
      ]

      request.set_form(form, "multipart/form-data")

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end
    end

    # ---------------------------------------------
    def self.generate_code(n)
      chars = ('A'..'Z').to_a + ('0'..'9').to_a
      Array.new(n) { chars.sample }.join
    end

    def self.copy_to_clipboard_safe(text)
      UI.copy_to_clipboard(text) rescue nil
    end

    unless file_loaded?(__FILE__)
      UI.menu("Plugins").add_item("#{PLUGIN_NAME} – Export VR") { export_and_upload }
      file_loaded(__FILE__)
    end

  end
end
