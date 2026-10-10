# HERE IS MY PARAGRAPH, in a game the player narrates: the player's words for a
# turn the game chose, handed to `Playthrough::Session#write_paragraph!`, which
# keeps them beside the turn and checks them against its facts. Nothing here
# decides anything: a scene the game did not choose, or a game told another
# way, is the engine's refusal, said back in its words. Writing costs no model
# call, so nothing is enqueued -- the page is drawn again with the paragraph
# and its note in the log.
class ParagraphsController < ApplicationController
  def create
    playthrough = Playthrough.find(params[:playthrough_id])
    scene = playthrough.story.scenes.find(params[:scene_id])
    Playthrough::Session.new(playthrough).write_paragraph!(scene, params[:text])
    redirect_to playthrough_path(playthrough, anchor: "bottom"), status: :see_other
  rescue Playthrough::RustEngine::EngineError => e
    redirect_to playthrough_path(playthrough, anchor: "bottom"), status: :see_other, alert: "That paragraph was not kept: #{e.message}."
  end
end
