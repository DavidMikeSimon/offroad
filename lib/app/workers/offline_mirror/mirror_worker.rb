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
				f = MirrorFile.create_up_mirror_for(options[:group])
				r.filename = f.save_to_tmp
				r.finished = true
			end
		end
		
		def generate_down_mirror_file(options)
			collect_results do |r|
				raise "Cannot generate down-mirror file when app in offline mode" if OfflineMirror::app_offline?
				f = MirrorFile.create_down_mirror_for(options[:group])
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
			update
		end
		
		def error=(v)
			@data[:error] = v
			update
		end
		
		def finished=(v)
			@data[:finished] = v
			update
		end

		def filename=(v)
			@data[:filename] = v
			update
		end
		
		private
		
		def update
			Workling.return.set(@uid, @data)
		end
	end
end
