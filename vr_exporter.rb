# vr_exporter.rb
#
# Plugin SketchUp : Export GLB + Upload vers serveur configuré
# par LMDDC

require "sketchup.rb"
require "tmpdir"
require "net/http"
require "uri"
require "json"
require "fileutils"

module LMDDC
  module VrExporter

    PLUGIN_NAME    = "VR Exporter"
    CODE_LENGTH    = 4

    CONFIG_DIR     = File.join(ENV["APPDATA"].to_s, "VRExporter")
    CONFIG_FILE    = File.join(CONFIG_DIR, "config.json")

    # ----------------------------------------------------------
    # Charger configuration (clé + URL)
    # ----------------------------------------------------------
    def self.get_config
      # Lecture config existante
      if File.exist?(CONFIG_FILE)
        begin
          cfg = JSON.parse(File.read(CONFIG_FILE))
          return cfg if cfg["api_key"] && cfg["api_url"]
        rescue
        end
      end

      # Sinon → demander les 2 valeurs
      prompts = ["Entrez votre API Key :", "Entrez l'URL d'upload :"]
      defaults = ["", "http://localhost:8088/upload_glb.php"]

      result = UI.inputbox(prompts, defaults, "Configuration VR Exporter")

      if result.nil?
        UI.messagebox("Configuration annulée.")
        return nil
      end

      api_key, api_url = result

      if api_key.strip.empty? || api_url.strip.empty?
        UI.messagebox("API Key ou URL invalide.")
        return nil
      end

      cfg = {
        "api_key" => api_key.strip,
        "api_url" => api_url.strip
      }

      FileUtils.mkdir_p(CONFIG_DIR)
      File.write(CONFIG_FILE, JSON.pretty_generate(cfg))

      cfg
    end

    # ----------------------------------------------------------
    # Popup HTML LMDDC (code géant)
    # ----------------------------------------------------------
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

            <h2 style="font-size:14px;">Voici le code à ouvrir dans la VR :</h2>

            <div style="font-size:72px; font-weight:bold; margin:15px 0;">
              #{code}
            </div>

            <button onclick="window.close()"
              style="
                margin-top:15px;
                padding:14px 20px;
                font-size:18px;
                background:white;
                color:#ff7a00;
                border:none;
                border-radius:8px;
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

    # ----------------------------------------------------------
    # Export + Upload
    # ----------------------------------------------------------
    def self.export_and_upload
      model = Sketchup.active_model
      return UI.messagebox("Aucun modèle actif.") unless model

      config = get_config
      return unless config

      api_key = config["api_key"]
      api_url = config["api_url"]

      code = generate_code(CODE_LENGTH)

      tmp = Dir.mktmpdir("vr_exporter")
      glb_path = File.join(tmp, "scene_#{code}.glb")

      exported = model.export(glb_path, triangulated_faces: true, texture_maps: true)
      unless exported && File.exist?(glb_path)
        UI.messagebox("Échec export GLB.")
        return
      end

      response = upload_glb(glb_path, code, api_key, api_url)

      if response.is_a?(Net::HTTPSuccess)
        begin
          data   = JSON.parse(response.body)
          result_code = data.dig("data", "code") || code

          show_big_message(result_code)
          copy_to_clipboard_safe(result_code)

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

    # ----------------------------------------------------------
    # Upload avec URL custom
    # ----------------------------------------------------------
    def self.upload_glb(file_path, code, api_key, api_url)
      uri = URI.parse(api_url)

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

    # ----------------------------------------------------------
    def self.generate_code(n)
      chars = ('A'..'Z').to_a + ('0'..'9').to_a
      Array.new(n) { chars.sample }.join
    end

    def self.copy_to_clipboard_safe(text)
      UI.copy_to_clipboard(text) rescue nil
    end

    # ----------------------------------------------------------
    unless file_loaded?(__FILE__)
      UI.menu("Plugins").add_item("#{PLUGIN_NAME} – Export VR") { export_and_upload }
      file_loaded(__FILE__)
    end

  end
end
