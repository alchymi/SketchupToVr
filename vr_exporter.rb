# vr_exporter.rb
#
# Plugin SketchUp : Export GLB + Upload via API Key
# Version simple & stable (sans HMAC)
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
    API_UPLOAD_URL = "https://glbup.funtools.cloud/upload_glb.php"
    CODE_LENGTH    = 4

    CONFIG_DIR     = File.join(ENV["APPDATA"].to_s, "VRExporter")
    CONFIG_FILE    = File.join(CONFIG_DIR, "config.json")

    # ----------------------------------------------------------------------
    # Lecture / Demande API Key
    # ----------------------------------------------------------------------
    def self.get_api_key
      if File.exist?(CONFIG_FILE)
        begin
          data = JSON.parse(File.read(CONFIG_FILE))
          return data["api_key"] if data["api_key"] && !data["api_key"].empty?
        rescue
        end
      end

      # Demande à l'utilisateur
      key = UI.inputbox(["Entrez votre API Key :"], [""])&.first

      if key.nil? || key.strip.empty?
        UI.messagebox("Aucune API Key fournie. Annulation.")
        return nil
      end

      FileUtils.mkdir_p(CONFIG_DIR)
      File.write(CONFIG_FILE, JSON.pretty_generate({ api_key: key }))

      key
    end

    # ----------------------------------------------------------------------
    # Popup HTML LMDDC (code en très grand)
    # ----------------------------------------------------------------------
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
                 width="120"
                 style="margin-bottom:25px;" />

            <h2 style="font-size:22px; font-weight:normal;">Voici le code à ouvrir dans la VR :</h2>

            <div style="font-size:72px; font-weight:bold; margin:30px 0;">#{code}</div>

            <div style="font-size:16px; opacity:0.9;">Made with love by LMDDC ❤️</div>

            <div style="margin-top:35px;">
                <button onclick="window.close()"
                  style="
                    padding:12px 25px;
                    font-size:16px;
                    background:white;
                    color:#ff7a00;
                    border:none;
                    border-radius:6px;
                    cursor:pointer;">
                  Fermer
                </button>
            </div>

        </body>
        </html>
      HTML

      dlg = UI::HtmlDialog.new(
        dialog_title: "Code VR",
        width: 430,
        height: 470,
        resizable: false
      )
      dlg.set_html(html)
      dlg.show
    end

    # ----------------------------------------------------------------------
    # Export + Upload
    # ----------------------------------------------------------------------
    def self.export_and_upload
      model = Sketchup.active_model
      unless model
        UI.messagebox("Aucun modèle actif.")
        return
      end

      api_key = get_api_key
      return unless api_key

      code = generate_code(CODE_LENGTH)

      tmp_dir  = Dir.mktmpdir("vr_exporter")
      glb_path = File.join(tmp_dir, "scene_#{code}.glb")

      exported = export_glb(model, glb_path)
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

    rescue => e
      UI.messagebox("Erreur plugin : #{e.message}")
    ensure
      cleanup_tmp(tmp_dir)
    end

    # ----------------------------------------------------------------------
    # Upload simple via API Key
    # ----------------------------------------------------------------------
    def self.upload_glb(file_path, code, api_key)
      uri = URI.parse(API_UPLOAD_URL)

      request = Net::HTTP::Post.new(uri)
      request["X-API-KEY"] = api_key

      form_data = [
        ["code", code],
        ["file", File.open(file_path)]
      ]

      request.set_form(form_data, "multipart/form-data")

      Net::HTTP.start(uri.hostname, uri.port,
                      use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end
    end

    # ----------------------------------------------------------------------
    def self.export_glb(model, glb_path)
      model.export(glb_path, triangulated_faces: true, texture_maps: true)
    end

    def self.cleanup_tmp(dir)
      return unless dir && Dir.exist?(dir)
      Dir.foreach(dir) do |f|
        next if f == "." || f == ".."
        File.delete(File.join(dir, f)) rescue nil
      end
      Dir.rmdir(dir) rescue nil
    end

    def self.generate_code(length)
      chars = ('A'..'Z').to_a + ('0'..'9').to_a
      Array.new(length) { chars.sample }.join
    end

    def self.copy_to_clipboard_safe(text)
      return unless UI.respond_to?(:copy_to_clipboard)
      UI.copy_to_clipboard(text)
    end

    unless file_loaded?(__FILE__)
      UI.menu("Plugins").add_item("#{PLUGIN_NAME} – Export VR") {
        self.export_and_upload
      }
      file_loaded(__FILE__)
    end

  end
end