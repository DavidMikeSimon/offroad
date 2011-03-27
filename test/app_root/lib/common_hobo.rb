module CommonHobo
  def self.included(base)
    base.class_eval do
      hobo_model
      attr_accessor :permissive
      def create_permitted?() @permissive; end
      def update_permitted?() @permissive; end
      def destroy_permitted?() @permissive; end
    end
  end
end
