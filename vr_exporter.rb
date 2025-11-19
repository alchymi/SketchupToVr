# vr_exporter.rb
#
# Plugin SketchUp : Exporter la scène en GLB + générer un code court + uploader via API

require "sketchup.rb"
require "tmpdir"
require "net/http"
require "uri"
require "json"

module MyCompany
  module VrExporter

    PLUGIN_NAME    = "VR Exporter"
    API_UPLOAD_URL = "http://localhost:4444/upload_glb.php"
    CODE_LENGTH    = 4  # 4 caractères (A-Z, 0-9)

    def self.export_and_upload
      model = Sketchup.active_model
      unless model
        UI.messagebox("Aucun modèle actif trouvé.")
        return
      end

      code = generate_code(CODE_LENGTH)

      tmp_dir = Dir.mktmpdir("vr_exporter")
      glb_path = File.join(tmp_dir, "scene_\#{code}.glb")

      UI.messagebox("Export GLB en cours, merci de patienter...")

      exported = export_glb(model, glb_path)

      unless exported && File.exist?(glb_path)
        UI.messagebox("Échec de l'export GLB. Vérifie le format ou l'exporteur.")
        return
      end

      UI.messagebox("Upload du fichier vers le serveur...")

      response = upload_glb(glb_path, code)

      if response.is_a?(Net::HTTPSuccess)
        begin
          data    = JSON.parse(response.body)
          payload = data["data"] || {}
          display_code = payload["code"] || code
          url          = payload["file_url"]
          msg          = data["message"] || "Upload réussi."

          big_msg = "\#{msg}\n\nIdentifiant : \#{display_code}"
          big_msg += "\nURL : \#{url}" if url

          UI.messagebox(big_msg)
          copy_to_clipboard_safe(display_code)
        rescue => e
          UI.messagebox("Upload OK, mais erreur JSON : \#{e.message}\nCode : \#{code}")
        end
      else
        UI.messagebox("Upload échoué : \#{response.code} - \#{response.body}")
      end

    rescue => e
      UI.messagebox("Erreur dans le plugin VR Exporter : \#{e.message}")
    ensure
      begin
        if tmp_dir && Dir.exist?(tmp_dir)
          Dir.foreach(tmp_dir) do |f|
            next if f == "." || f == ".."
            File.delete(File.join(tmp_dir, f)) rescue nil
          end
          Dir.rmdir(tmp_dir) rescue nil
        end
      rescue
      end
    end

    def self.export_glb(model, glb_path)
      options = {
        :triangulated_faces => true,
        :texture_maps       => true
      }
      model.export(glb_path, options)
    end

    def self.generate_code(length = 4)
      chars = ('A'..'Z').to_a + ('0'..'9').to_a
      Array.new(length) { chars.sample }.join
    end

    def self.upload_glb(file_path, code)
      uri = URI.parse(API_UPLOAD_URL)

      request = Net::HTTP::Post.new(uri)

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

    def self.copy_to_clipboard_safe(text)
      if UI.respond_to?(:copy_to_clipboard)
        UI.copy_to_clipboard(text)
        UI.messagebox("Le code \#{text} a été copié dans le presse-papier.")
      end
    end

    unless file_loaded?(__FILE__)
      menu = UI.menu("Plugins")
      menu.add_item("\#{PLUGIN_NAME} - by LMDDC") do
        self.export_and_upload
      end
      file_loaded(__FILE__)
    end

  end
end
