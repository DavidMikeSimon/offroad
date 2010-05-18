module OfflineMirror
	class MirrorWorker < Workling::Base
		def load_up_mirror_file(options)
			collect_results do |r|
				raise "Cannot load up-mirror file when app in offline mode" if OfflineMirror::app_offline?
			end
		end
		
		def load_down_mirror_file(options)
			collect_results do |r|
				raise "Cannot load down-mirror file when app in online mode" if OfflineMirror::app_online?
			end
		end
		
		def generate_up_mirror_file(options)
			collect_results do |r|
				raise "Cannot generate up-mirror file when app in online mode" if OfflineMirror::app_online?
				f = MirrorFile.new(OfflineMirror::offline_group_state)
				f.set_standard_title("Uploadable")
				f.message = "<p>This is a " + OfflineMirror::app_name + " data file for upload.</p>"
				f.message += "<p>Please use the website at <a href=\"" + OfflineMirror::online_url + "\">" + OfflineMirror::online_url + "</a> to upload it.</p>"
				r.filename = f.save_to_tmp
				r.finished = true
			end
		end
		
		def generate_down_mirror_file(options)
			collect_results do |r|
				raise "Cannot generate down-mirror file when app in offline mode" if OfflineMirror::app_offline?
				r.filename = f.save_to_tmp
				r.finished = true
			end
		end
		
		private
		
		def collect_results(uid)
			results_setter = MirrorWorkerResultsSetter.new(uid)
			yield results_setter
		rescue Exception => e
			results_setter.error = e
			raise
		ensure
			results_setter.update
		end
	end
	
	class MirrorWorkerResults
		def initialize(uid)
			@data = {}
			update
		end
		
		def error?
			update
			@data[:error]
		end
		
		def finished?
			update
			@data[:finished]
		end

		def filename
			update
			@data[:filename]
		end
		
		private
		
		def update
			v = Working.return.get(@uid)
			@data = v if v
			raise @data[:error] if @data[:error]
		end
	end
	
	private
	
	class MirrorWorkerResultsSetter
		def initialize(uid)
			@uid = uid
			@data = {}
		end
		
		def error=(v)
			@data[:error] = v
		end
		
		def finished=(v)
			@data[:finished] = v
		end

		def filename=(v)
			@data[:filename] = v
		end
		
		def update
			Workling.return.set(@uid, @data)
		end
	end
end
