# vr_exporter.rb
#
# Plugin SketchUp : Export GLB + Upload sécurisé via API KEY + Popup HTML LMDDC

require "sketchup.rb"
require "tmpdir"
require "net/http"
require "uri"
require "json"
require "fileutils"

module MyCompany
  module VrExporter

    PLUGIN_NAME    = "VR Exporter"
    API_UPLOAD_URL = "https://glbup.funtools.cloud/upload_glb.php"
    CODE_LENGTH    = 4

    CONFIG_DIR  = File.join(ENV["APPDATA"].to_s, "VRExporter")
    CONFIG_FILE = File.join(CONFIG_DIR, "config.json")

    # ----------------------------------------------------------------------
    # API KEY : chargement ou demande (popup 1 seule fois)
    # ----------------------------------------------------------------------
    def self.get_api_key
      # Déjà enregistrée ?
      if File.exist?(CONFIG_FILE)
        begin
          data = JSON.parse(File.read(CONFIG_FILE))
          return data["api_key"] if data["api_key"] && !data["api_key"].empty?
        rescue
        end
      end

      # Sinon on la demande
      key = UI.inputbox(["Entrez votre API Key :"], [""])&.first
      if key.nil? || key.strip.empty?
        UI.messagebox("Aucune API Key fournie. Annulation.")
        return nil
      end

      save_api_key(key)
      key
    end

    def self.save_api_key(key)
      FileUtils.mkdir_p(CONFIG_DIR)
      File.open(CONFIG_FILE, "w") do |f|
        f.write(JSON.pretty_generate({ api_key: key }))
      end
    end

    # ----------------------------------------------------------------------
    # Popup HTML LMDDC — Code affiché en GRAND
    # ----------------------------------------------------------------------
    def self.show_big_message(code)
      html = <<-HTML
        <html>
          <body style="
            font-family:Arial;
            background:#ff7a00;
            color:white;
            padding:30px;
            text-align:center;
          ">

            <!-- LOGO LMDDC -->
            <img src="https://www.lmddc.lu/images/logo_lmddc_white.svg"
                 width="200"
                 style="margin-bottom:25px;" />

            <h2 style="margin-top:10px; font-size:10px; font-weight:normal;">
              Voici le code à ouvrir dans la VR :
            </h2>

            <div style="
              font-size:72px;
              font-weight:bold;
              margin-top:30px;
              margin-bottom:30px;
            ">
              #{code}
            </div>

            <div style="font-size:10px; opacity:0.9;">
              Made with love by LMDDC ❤️
            </div>

            <div style="margin-top:10px;">
              <button onclick="window.close()"
                style="
                  padding:12px 28px;
                  font-size:16px;
                  cursor:pointer;
                  background:white;
                  color:#ff7a00;
                  border:none;
                  font-weight:bold;
                  border-radius:6px;
                ">
                Fermer
              </button>
            </div>

          </body>
        </html>
      HTML

      dlg = UI::HtmlDialog.new(
        dialog_title: "Code VR",
        width: 430,
        height: 570,
        resizable: true
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
        UI.messagebox("Échec de l'export GLB.")
        return
      end

      # Upload sécurisé
      response = upload_glb(glb_path, code, api_key)

      if response.is_a?(Net::HTTPSuccess)
        begin
          data    = JSON.parse(response.body)
          payload = data["data"] || {}
          display_code = payload["code"] || code

          # Popup finale LMDDC
          show_big_message(display_code)

          copy_to_clipboard_safe(display_code)

        rescue => e
          UI.messagebox("Upload OK mais JSON invalide : #{e.message}")
        end
      else
        UI.messagebox("Upload échoué : #{response.code}\n#{response.body}")
      end

    rescue => e
      UI.messagebox("Erreur plugin VR Exporter : #{e.message}")
    ensure
      cleanup_tmp(tmp_dir)
    end

    # ----------------------------------------------------------------------
    # Nettoyage
    # ----------------------------------------------------------------------
    def self.cleanup_tmp(dir)
      return unless dir && Dir.exist?(dir)
      Dir.foreach(dir) do |f|
        next if f == "." || f == ".."
        File.delete(File.join(dir, f)) rescue nil
      end
      Dir.rmdir(dir) rescue nil
    end

    # ----------------------------------------------------------------------
    # Export GLB
    # ----------------------------------------------------------------------
    def self.export_glb(model, glb_path)
      options = {
        :triangulated_faces => true,
        :texture_maps       => true
      }
      model.export(glb_path, options)
    end

    # ----------------------------------------------------------------------
    # Génération du code
    # ----------------------------------------------------------------------
    def self.generate_code(length = 4)
      chars = ('A'..'Z').to_a + ('0'..'9').to_a
      Array.new(length) { chars.sample }.join
    end

    # ----------------------------------------------------------------------
    # Upload GLB via API sécurisée
    # ----------------------------------------------------------------------
    def self.upload_glb(file_path, code, api_key)
      uri = URI.parse(API_UPLOAD_URL)

      request = Net::HTTP::Post.new(uri)
      request["X-API-KEY"] = api_key  # Sécurité

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
    # Copy to clipboard
    # ----------------------------------------------------------------------
    def self.copy_to_clipboard_safe(text)
      return unless UI.respond_to?(:copy_to_clipboard)
      UI.copy_to_clipboard(text)
      UI.messagebox("Le code #{text} a été copié dans le presse-papier.")
    end

    # ----------------------------------------------------------------------
    # Ajout menu SketchUp
    # ----------------------------------------------------------------------
    unless file_loaded?(__FILE__)
      menu = UI.menu("Plugins")
      menu.add_item("#{PLUGIN_NAME} – Export VR") do
        self.export_and_upload
      end
      file_loaded(__FILE__)
    end

  end
end
