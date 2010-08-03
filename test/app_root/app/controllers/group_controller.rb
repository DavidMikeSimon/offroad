class GroupController < OfflineMirror::GroupBaseController
  def download_down_mirror
    render_down_mirror_file Group.find(params[:id]), "down-mirror-file", :layout => "mirror"
  end
  
  def download_up_mirror
    render_up_mirror_file Group.find(params[:id]), "up-mirror-file", :layout => "mirror"
  end
  
  def upload_up_mirror
    load_up_mirror_file Group.find(params[:id]), params[:mirror_data]
  end
  
  def upload_down_mirror
    load_down_mirror_file Group.find(params[:id]), params[:mirror_data]
  end
  
  def upload_initial_down_mirror
    load_down_mirror_file nil, params[:mirror_data]
    render :upload_down_mirror
  end
end