# vr_exporter.rb
#
# Plugin SketchUp : Export GLB + Upload sécurisé (HMAC SHA256)
# by LMDDC

require "sketchup.rb"
require "tmpdir"
require "net/http"
require "uri"
require "json"
require "fileutils"
require "openssl"
require "digest"

module LMDDC
  module VrExporter

    PLUGIN_NAME       = "VR Exporter"
    API_UPLOAD_URL    = "https://glbup.funtools.cloud/upload_glb.php"
    CODE_LENGTH       = 4

    CONFIG_DIR        = File.join(ENV["APPDATA"].to_s, "VRExporter")
    CONFIG_FILE       = File.join(CONFIG_DIR, "config.json")
    SECRET_FILE       = File.join(CONFIG_DIR, "secret.key")

    # ----------------------------------------------------------------------
    # Charger la config (public key) et clé secrète (HMAC)
    # ----------------------------------------------------------------------
    def self.get_credentials
      unless File.exist?(CONFIG_FILE)
        public_key = UI.inputbox(["Public API Key :"], [""])&.first
        if public_key.nil? || public_key.strip.empty?
          UI.messagebox("Aucune Public Key fournie. Annulation.")
          return nil
        end

        FileUtils.mkdir_p(CONFIG_DIR)
        File.write(CONFIG_FILE, JSON.pretty_generate({ public_key: public_key }))
      end

      unless File.exist?(SECRET_FILE)
        secret = UI.inputbox(["Secret Key (HMAC) :"], [""])&.first
        if secret.nil? || secret.strip.empty?
          UI.messagebox("Aucune Secret Key fournie. Annulation.")
          return nil
        end

        File.write(SECRET_FILE, secret)
      end

      cfg = JSON.parse(File.read(CONFIG_FILE))
      public_key = cfg["public_key"]
      secret_key = File.read(SECRET_FILE).strip

      return [public_key, secret_key]
    end

    # ----------------------------------------------------------------------
    # Popup HTML LMDDC
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
                 width="160" style="margin-bottom:15px;" />

            <h2 style="font-size:10px; font-weight:normal;">
              Voici le code à ouvrir dans la VR :
            </h2>

            <div style="font-size:72px; font-weight:bold; margin:30px 0;">
              #{code}
            </div>

            <div style="font-size:10px; opacity:0.9;">
              Made with love by LMDDC ❤️
            </div>

            <div style="margin-top:15px;">
              <button onclick="window.close()"
                style="
                  padding:8px 8px;
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
    def self.export_and_upload
      model = Sketchup.active_model
      unless model
        UI.messagebox("Aucun modèle actif.")
        return
      end

      public_key, secret_key = get_credentials
      return unless public_key && secret_key

      code = generate_code(CODE_LENGTH)

      tmp_dir  = Dir.mktmpdir("vr_exporter")
      glb_path = File.join(tmp_dir, "scene_#{code}.glb")

      exported = export_glb(model, glb_path)
      unless exported && File.exist?(glb_path)
        UI.messagebox("Échec export GLB.")
        return
      end

      response = upload_glb(glb_path, code, public_key, secret_key)

      if response.is_a?(Net::HTTPSuccess)
        begin
          data = JSON.parse(response.body)
          display_code = data["data"]["code"] rescue code

          show_big_message(display_code)
          copy_to_clipboard_safe(display_code)

        rescue => e
          UI.messagebox("Upload OK mais JSON invalide : #{e.message}")
        end
      else
        UI.messagebox("Erreur upload : #{response.code}")
      end

    rescue => e
      UI.messagebox("Erreur plugin : #{e.message}")
    ensure
      cleanup_tmp(tmp_dir)
    end

    # ----------------------------------------------------------------------
    def self.upload_glb(file_path, code, public_key, secret_key)
      uri = URI.parse(API_UPLOAD_URL)

      timestamp   = Time.now.to_i.to_s
      file_hash   = Digest::SHA256.file(file_path).hexdigest
      payload     = "#{timestamp}:#{code}:#{file_hash}"
      signature   = OpenSSL::HMAC.hexdigest("SHA256", secret_key, payload)

      request = Net::HTTP::Post.new(uri)
      request["X-API-KEY"]       = public_key
      request["X-API-TIMESTAMP"] = timestamp
      request["X-API-SIGNATURE"] = signature

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
      options = { triangulated_faces: true, texture_maps: true }
      model.export(glb_path, options)
    end

    def self.cleanup_tmp(dir)
      return unless dir && Dir.exist?(dir)
      Dir.foreach(dir) do |f|
        next if f == "." || f == ".."
        File.delete(File.join(dir, f)) rescue nil
      end
      Dir.rmdir(dir) rescue nil
    end

    def self.generate_code(length=4)
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
