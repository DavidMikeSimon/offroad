class GroupController < OfflineMirror::GroupBaseController
  def download_down_mirror
    group = Group.find(params[:id])
    render_down_mirror_file group, "down-mirror-file", :layout => "mirror"
  end
end