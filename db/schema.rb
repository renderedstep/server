# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_30_120000) do
  create_table "characters", force: :cascade do |t|
    t.integer "story_id", null: false
    t.string "fullname"
    t.string "nickname"
    t.integer "age"
    t.string "sex"
    t.text "personality"
    t.text "appearance"
    t.text "likes"
    t.text "dislikes"
    t.text "fears"
    t.text "backstory"
    t.boolean "is_companion"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "race_id", null: false
    t.boolean "is_protagonist", default: false, null: false
    t.integer "location_id"
    t.boolean "deliberately_absent", default: false, null: false
    t.integer "level"
    t.integer "hit_die"
    t.integer "strength"
    t.integer "dexterity"
    t.integer "will"
    t.boolean "hostile", default: false, null: false
    t.integer "x"
    t.integer "y"
    t.text "conscious_desire"
    t.text "unconscious_desire"
    t.text "recognized_need"
    t.text "unrecognized_need"
    t.string "desire_pursuit"
    t.string "need_pursuit"
    t.index "story_id, LOWER(fullname)", name: "index_characters_on_story_id_and_lower_fullname", unique: true
    t.index ["location_id", "hostile"], name: "index_characters_on_location_id_and_hostile"
    t.index ["location_id", "id"], name: "index_characters_on_location_id_and_id"
    t.index ["location_id"], name: "index_characters_on_location_id"
    t.index ["race_id"], name: "index_characters_on_race_id"
    t.index ["story_id", "is_protagonist"], name: "index_characters_on_story_id_and_is_protagonist"
    t.index ["story_id"], name: "index_characters_on_story_id"
  end

  create_table "characters_scenes", id: false, force: :cascade do |t|
    t.integer "character_id", null: false
    t.integer "scene_id", null: false
    t.index ["character_id", "scene_id"], name: "index_characters_scenes_on_character_id_and_scene_id"
    t.index ["scene_id", "character_id"], name: "index_characters_scenes_on_scene_id_and_character_id"
  end

  create_table "chats", force: :cascade do |t|
    t.string "model_id_string"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "ruby_llm_model_id"
    t.string "purpose"
    t.integer "playthrough_id"
    t.integer "character_id"
    t.boolean "cancelled", default: false, null: false
    t.integer "player_id"
    t.index ["character_id"], name: "index_chats_on_character_id"
    t.index ["player_id"], name: "index_chats_on_player_id"
    t.index ["playthrough_id", "character_id", "purpose"], name: "index_chats_on_conversation_key"
    t.index ["playthrough_id"], name: "index_chats_on_playthrough_id"
    t.index ["ruby_llm_model_id"], name: "index_chats_on_ruby_llm_model_id"
  end

  create_table "interactions", force: :cascade do |t|
    t.integer "character_id", null: false
    t.integer "scene_id"
    t.integer "location_id"
    t.text "pre_thought"
    t.text "pre_feeling"
    t.text "action"
    t.text "post_feeling"
    t.text "post_thought"
    t.text "inner_resolution"
    t.text "summary"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "user_input"
    t.string "engine_action"
    t.string "action_status"
    t.text "action_fact"
    t.index ["character_id"], name: "index_interactions_on_character_id"
    t.index ["location_id"], name: "index_interactions_on_location_id"
    t.index ["scene_id"], name: "index_interactions_on_scene_id"
  end

  create_table "items", force: :cascade do |t|
    t.integer "character_id"
    t.string "name"
    t.text "description"
    t.text "properties"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "location_id"
    t.integer "playthrough_id"
    t.boolean "readable", default: false, null: false
    t.text "inscription"
    t.integer "template_id"
    t.string "bulk", default: "handy", null: false
    t.integer "x"
    t.integer "y"
    t.string "use_kind", default: "ordinary", null: false
    t.boolean "combustible", default: false, null: false
    t.string "disposition", default: "intact", null: false
    t.string "fragility", default: "sturdy", null: false
    t.string "tier", default: "portable", null: false
    t.string "holds"
    t.integer "within_id"
    t.string "how"
    t.string "kit_key"
    t.datetime "noticed_at"
    t.datetime "searched_at"
    t.string "hold"
    t.string "material"
    t.string "wear"
    t.boolean "worn", default: false, null: false
    t.index ["character_id"], name: "index_items_on_character_id"
    t.index ["location_id", "character_id"], name: "index_items_on_location_id_and_character_id"
    t.index ["location_id"], name: "index_items_on_location_id"
    t.index ["playthrough_id", "id"], name: "index_items_on_playthrough_id_and_id"
    t.index ["playthrough_id", "template_id"], name: "index_items_on_playthrough_id_and_template_id"
    t.index ["playthrough_id"], name: "index_items_on_playthrough_id"
    t.index ["template_id"], name: "index_items_on_template_id"
    t.index ["within_id"], name: "index_items_on_within_id"
  end

  create_table "lab_exits_judgements", force: :cascade do |t|
    t.integer "vantage_id", null: false
    t.string "name", null: false
    t.string "name_key", null: false
    t.text "expects_inside"
    t.text "expects_population"
    t.string "verdict"
    t.text "aspects"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["vantage_id", "name_key"], name: "index_lab_exits_judgements_on_place", unique: true
    t.index ["vantage_id"], name: "index_lab_exits_judgements_on_vantage_id"
  end

  create_table "lab_exits_samples", force: :cascade do |t|
    t.integer "vantage_id", null: false
    t.json "row", default: {}, null: false
    t.string "verdict"
    t.text "aspects"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["vantage_id"], name: "index_lab_exits_samples_on_vantage_id"
  end

  create_table "lab_exits_vantages", force: :cascade do |t|
    t.string "world", null: false
    t.string "name", null: false
    t.text "teaser", null: false
    t.string "reached_from"
    t.string "danger"
    t.text "absent"
    t.string "expects_inside_quantifier"
    t.text "expects_population"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "lab_realization_kinds", force: :cascade do |t|
    t.string "world", null: false
    t.string "name", null: false
    t.text "teaser", null: false
    t.string "reached_from"
    t.string "inside"
    t.string "danger"
    t.string "population"
    t.text "expects_inside"
    t.text "expects_population"
    t.text "expects_storeys_above"
    t.text "expects_storeys_below"
    t.text "expects_danger"
    t.text "expects_gradient"
    t.text "expects_hazard"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "lab_realization_samples", force: :cascade do |t|
    t.integer "kind_id", null: false
    t.json "row", default: {}, null: false
    t.string "verdict"
    t.text "aspects"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind_id"], name: "index_lab_realization_samples_on_kind_id"
  end

  create_table "location_connections", force: :cascade do |t|
    t.integer "location_id", null: false
    t.integer "connected_location_id", null: false
    t.text "distance"
    t.text "time_to_travel"
    t.text "travel_method"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "hazard"
    t.integer "hazard_die"
    t.string "barrier", default: "open", null: false
    t.integer "key_template_id"
    t.index ["connected_location_id"], name: "index_location_connections_on_connected_location_id"
    t.index ["key_template_id"], name: "index_location_connections_on_key_template_id"
    t.index ["location_id", "connected_location_id"], name: "idx_on_location_id_connected_location_id_a0efda2bf6", unique: true
    t.index ["location_id"], name: "index_location_connections_on_location_id"
  end

  create_table "locations", force: :cascade do |t|
    t.integer "story_id", null: false
    t.string "name"
    t.text "description"
    t.text "lore"
    t.datetime "last_protagonist_visit"
    t.integer "parent_location_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "detail_level", default: "stub", null: false
    t.text "teaser"
    t.boolean "mobile", default: false, null: false
    t.string "danger", default: "safe", null: false
    t.string "hazard"
    t.integer "hazard_die"
    t.integer "x"
    t.integer "y"
    t.integer "z"
    t.integer "width"
    t.integer "depth"
    t.string "population"
    t.json "generation_checkpoint"
    t.string "surface"
    t.string "kind"
    t.string "density"
    t.index "story_id, lower(name)", name: "index_locations_on_story_id_and_lower_name", unique: true
    t.index ["parent_location_id"], name: "index_locations_on_parent_location_id"
    t.index ["story_id", "detail_level"], name: "index_locations_on_story_id_and_detail_level"
    t.index ["story_id"], name: "index_locations_on_story_id"
  end

  create_table "locations_world_events", id: false, force: :cascade do |t|
    t.integer "location_id", null: false
    t.integer "world_event_id", null: false
    t.index ["location_id"], name: "index_locations_world_events_on_location_id"
    t.index ["world_event_id", "location_id"], name: "index_locations_world_events_on_world_event_id_and_location_id", unique: true
    t.index ["world_event_id"], name: "index_locations_world_events_on_world_event_id"
  end

  create_table "messages", force: :cascade do |t|
    t.integer "chat_id", null: false
    t.string "role"
    t.text "content"
    t.string "model_id_string"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.integer "tool_call_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "model_id"
    t.integer "scene_id"
    t.json "content_raw"
    t.boolean "cache_until_here", default: false, null: false
    t.string "finish_reason"
    t.json "citations"
    t.json "server_tool_calls"
    t.json "raw_content"
    t.json "raw_reasoning"
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["model_id"], name: "index_messages_on_model_id"
    t.index ["scene_id"], name: "index_messages_on_scene_id"
    t.index ["tool_call_id"], name: "index_messages_on_tool_call_id"
  end

  create_table "players", force: :cascade do |t|
    t.string "name", null: false
    t.string "token_digest", null: false
    t.decimal "monthly_limit_usd", precision: 10, scale: 4, default: "1.0", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_players_on_name", unique: true
    t.index ["token_digest"], name: "index_players_on_token_digest", unique: true
  end

  create_table "playthrough_beats", force: :cascade do |t|
    t.integer "playthrough_id", null: false
    t.integer "quest_step_id", null: false
    t.datetime "reached_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["playthrough_id", "quest_step_id"], name: "index_playthrough_beats_on_playthrough_id_and_quest_step_id", unique: true
    t.index ["playthrough_id"], name: "index_playthrough_beats_on_playthrough_id"
    t.index ["quest_step_id"], name: "index_playthrough_beats_on_quest_step_id"
  end

  create_table "playthrough_blows", force: :cascade do |t|
    t.integer "playthrough_id", null: false
    t.integer "attacker_id", null: false
    t.integer "target_id", null: false
    t.integer "location_id", null: false
    t.integer "damage", null: false
    t.integer "hp_after", null: false
    t.integer "round", null: false
    t.integer "sequence", null: false
    t.datetime "story_timestamp", null: false
    t.integer "scene_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attacker_id"], name: "index_playthrough_blows_on_attacker_id"
    t.index ["location_id"], name: "index_playthrough_blows_on_location_id"
    t.index ["playthrough_id", "scene_id", "id"], name: "index_playthrough_blows_on_playthrough_and_scene"
    t.index ["playthrough_id"], name: "index_playthrough_blows_on_playthrough_id"
    t.index ["scene_id"], name: "index_playthrough_blows_on_scene_id"
    t.index ["target_id"], name: "index_playthrough_blows_on_target_id"
  end

  create_table "playthrough_commands", force: :cascade do |t|
    t.integer "playthrough_id", null: false
    t.string "request_token", null: false
    t.text "command", null: false
    t.string "status", default: "pending", null: false
    t.integer "result_scene_id"
    t.json "refusal", default: {}, null: false
    t.string "error_kind"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "journal", default: {}, null: false
    t.index ["playthrough_id", "request_token", "command"], name: "index_playthrough_commands_on_submission", unique: true
    t.index ["playthrough_id"], name: "index_playthrough_commands_on_playthrough_id"
    t.index ["result_scene_id"], name: "index_playthrough_commands_on_result_scene_id"
  end

  create_table "playthrough_drifts", force: :cascade do |t|
    t.integer "playthrough_id", null: false
    t.integer "scene_id"
    t.integer "location_id"
    t.string "action", null: false
    t.text "command", null: false
    t.text "offered"
    t.datetime "story_timestamp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_playthrough_drifts_on_action"
    t.index ["location_id"], name: "index_playthrough_drifts_on_location_id"
    t.index ["playthrough_id", "story_timestamp"], name: "index_playthrough_drifts_on_playthrough_id_and_story_timestamp"
    t.index ["playthrough_id"], name: "index_playthrough_drifts_on_playthrough_id"
    t.index ["scene_id"], name: "index_playthrough_drifts_on_scene_id"
  end

  create_table "playthrough_due_endings", force: :cascade do |t|
    t.integer "playthrough_id", null: false
    t.integer "quest_outcome_id", null: false
    t.datetime "due_at", null: false
    t.datetime "declined_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["playthrough_id"], name: "index_playthrough_due_endings_on_playthrough_id", unique: true
    t.index ["quest_outcome_id"], name: "index_playthrough_due_endings_on_quest_outcome_id"
  end

  create_table "playthrough_endings", force: :cascade do |t|
    t.integer "playthrough_id", null: false
    t.integer "quest_outcome_id", null: false
    t.datetime "reached_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["playthrough_id", "quest_outcome_id"], name: "idx_on_playthrough_id_quest_outcome_id_7ea31b4171", unique: true
    t.index ["playthrough_id"], name: "index_playthrough_endings_on_playthrough_id"
    t.index ["quest_outcome_id"], name: "index_playthrough_endings_on_quest_outcome_id"
  end

  create_table "playthrough_feedbacks", force: :cascade do |t|
    t.integer "playthrough_id", null: false
    t.integer "scene_id", null: false
    t.string "verdict", null: false
    t.text "note"
    t.string "prose_model"
    t.string "prose_purpose"
    t.text "prose_models"
    t.text "answering_models"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "prose_prompt_digest"
    t.index ["playthrough_id", "scene_id"], name: "index_playthrough_feedbacks_on_playthrough_id_and_scene_id", unique: true
    t.index ["playthrough_id"], name: "index_playthrough_feedbacks_on_playthrough_id"
    t.index ["prose_model"], name: "index_playthrough_feedbacks_on_prose_model"
    t.index ["prose_prompt_digest"], name: "index_playthrough_feedbacks_on_prose_prompt_digest"
    t.index ["scene_id"], name: "index_playthrough_feedbacks_on_scene_id"
    t.index ["verdict"], name: "index_playthrough_feedbacks_on_verdict"
  end

  create_table "playthrough_npc_states", force: :cascade do |t|
    t.integer "playthrough_id", null: false
    t.integer "character_id", null: false
    t.integer "location_id"
    t.boolean "following", default: false, null: false
    t.boolean "ceasefire", default: false, null: false
    t.integer "peace_after_blow_id", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "noticed_at"
    t.index ["character_id"], name: "index_playthrough_npc_states_on_character_id"
    t.index ["location_id"], name: "index_playthrough_npc_states_on_location_id"
    t.index ["playthrough_id", "character_id"], name: "idx_on_playthrough_id_character_id_008ae03862", unique: true
    t.index ["playthrough_id"], name: "index_playthrough_npc_states_on_playthrough_id"
  end

  create_table "playthrough_overreaches", force: :cascade do |t|
    t.integer "playthrough_id", null: false
    t.integer "scene_id"
    t.integer "location_id"
    t.string "action", null: false
    t.text "command", null: false
    t.text "acted", null: false
    t.text "unacted", null: false
    t.datetime "story_timestamp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_playthrough_overreaches_on_action"
    t.index ["location_id"], name: "index_playthrough_overreaches_on_location_id"
    t.index ["playthrough_id", "story_timestamp"], name: "idx_on_playthrough_id_story_timestamp_b54cd36315"
    t.index ["playthrough_id"], name: "index_playthrough_overreaches_on_playthrough_id"
    t.index ["scene_id"], name: "index_playthrough_overreaches_on_scene_id"
  end

  create_table "playthrough_paragraphs", force: :cascade do |t|
    t.integer "playthrough_id", null: false
    t.integer "scene_id", null: false
    t.string "author", default: "player", null: false
    t.text "text", null: false
    t.json "audit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "consent", default: "none", null: false
    t.json "requests"
    t.string "prompt_digest"
    t.index ["playthrough_id"], name: "index_playthrough_paragraphs_on_playthrough_id"
    t.index ["scene_id", "author"], name: "index_playthrough_paragraphs_on_scene_id_and_author", unique: true
  end

  create_table "playthrough_passages", force: :cascade do |t|
    t.integer "playthrough_id", null: false
    t.integer "location_connection_id", null: false
    t.integer "opened_by_item_id"
    t.string "means", null: false
    t.datetime "opened_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_connection_id"], name: "index_playthrough_passages_on_location_connection_id"
    t.index ["opened_by_item_id"], name: "index_playthrough_passages_on_opened_by_item_id"
    t.index ["playthrough_id", "location_connection_id"], name: "idx_on_playthrough_id_location_connection_id_6d3a29d910", unique: true
    t.index ["playthrough_id"], name: "index_playthrough_passages_on_playthrough_id"
  end

  create_table "playthrough_tolls", force: :cascade do |t|
    t.integer "playthrough_id", null: false
    t.integer "character_id", null: false
    t.integer "location_id", null: false
    t.integer "location_connection_id"
    t.string "hazard", null: false
    t.boolean "saved", default: false, null: false
    t.integer "damage", null: false
    t.integer "hp_after", null: false
    t.integer "sequence", null: false
    t.datetime "story_timestamp", null: false
    t.integer "scene_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["character_id"], name: "index_playthrough_tolls_on_character_id"
    t.index ["location_connection_id"], name: "index_playthrough_tolls_on_location_connection_id"
    t.index ["location_id"], name: "index_playthrough_tolls_on_location_id"
    t.index ["playthrough_id", "scene_id", "id"], name: "index_playthrough_tolls_on_playthrough_and_scene"
    t.index ["playthrough_id"], name: "index_playthrough_tolls_on_playthrough_id"
    t.index ["scene_id"], name: "index_playthrough_tolls_on_scene_id"
  end

  create_table "playthrough_turn_events", force: :cascade do |t|
    t.integer "playthrough_command_id", null: false
    t.integer "sequence", null: false
    t.string "kind", null: false
    t.json "data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["playthrough_command_id", "sequence"], name: "index_playthrough_turn_events_on_command_and_sequence", unique: true
    t.index ["playthrough_command_id"], name: "index_playthrough_turn_events_on_playthrough_command_id"
  end

  create_table "playthrough_visits", force: :cascade do |t|
    t.integer "playthrough_id", null: false
    t.integer "location_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_playthrough_visits_on_location_id"
    t.index ["playthrough_id", "location_id"], name: "index_playthrough_visits_on_playthrough_and_location", unique: true
    t.index ["playthrough_id"], name: "index_playthrough_visits_on_playthrough_id"
  end

  create_table "playthrough_vitals", force: :cascade do |t|
    t.integer "playthrough_id", null: false
    t.integer "character_id", null: false
    t.integer "hp_current", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "provoked_at"
    t.index ["character_id"], name: "index_playthrough_vitals_on_character_id"
    t.index ["playthrough_id", "character_id"], name: "index_playthrough_vitals_on_playthrough_and_character", unique: true
    t.index ["playthrough_id"], name: "index_playthrough_vitals_on_playthrough_id"
  end

  create_table "playthrough_volitions", force: :cascade do |t|
    t.integer "playthrough_id", null: false
    t.integer "character_id", null: false
    t.integer "location_id", null: false
    t.integer "scene_id"
    t.string "chosen", null: false
    t.string "status", null: false
    t.text "fact", null: false
    t.string "serves", null: false
    t.integer "round", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "decided_by"
    t.string "system_one_error"
    t.index ["character_id"], name: "index_playthrough_volitions_on_character_id"
    t.index ["location_id"], name: "index_playthrough_volitions_on_location_id"
    t.index ["playthrough_id", "scene_id", "id"], name: "index_playthrough_volitions_on_playthrough_and_scene"
    t.index ["playthrough_id"], name: "index_playthrough_volitions_on_playthrough_id"
    t.index ["scene_id"], name: "index_playthrough_volitions_on_scene_id"
  end

  create_table "playthroughs", force: :cascade do |t|
    t.integer "story_id", null: false
    t.integer "character_id"
    t.integer "current_location_id"
    t.integer "current_scene_id"
    t.string "token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "ended_at"
    t.integer "player_id"
    t.string "mode", default: "narrated", null: false
    t.index ["character_id"], name: "index_playthroughs_on_character_id"
    t.index ["current_location_id"], name: "index_playthroughs_on_current_location_id"
    t.index ["current_scene_id"], name: "index_playthroughs_on_current_scene_id"
    t.index ["player_id"], name: "index_playthroughs_on_player_id"
    t.index ["story_id"], name: "index_playthroughs_on_story_id"
    t.index ["token"], name: "index_playthroughs_on_token", unique: true
  end

  create_table "quest_outcomes", force: :cascade do |t|
    t.integer "quest_id", null: false
    t.string "name", null: false
    t.text "summary", null: false
    t.boolean "is_default", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "condition"
    t.integer "minutes"
    t.text "ramification_summary"
    t.integer "ramification_minutes"
    t.integer "step_position"
    t.integer "character_id"
    t.index ["character_id"], name: "index_quest_outcomes_on_character_id"
    t.index ["quest_id", "name"], name: "index_quest_outcomes_on_quest_id_and_name", unique: true
    t.index ["quest_id"], name: "index_quest_outcomes_on_quest_id"
  end

  create_table "quest_steps", force: :cascade do |t|
    t.integer "quest_id", null: false
    t.integer "position", null: false
    t.text "summary", null: false
    t.string "trigger_kind", null: false
    t.string "target_name"
    t.text "teaser"
    t.string "target_type"
    t.integer "target_id"
    t.integer "minutes"
    t.datetime "bound_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "companion_id"
    t.index ["companion_id"], name: "index_quest_steps_on_companion_id"
    t.index ["quest_id", "position"], name: "index_quest_steps_on_quest_id_and_position", unique: true
    t.index ["quest_id"], name: "index_quest_steps_on_quest_id"
    t.index ["target_type", "target_id"], name: "index_quest_steps_on_target"
  end

  create_table "quests", force: :cascade do |t|
    t.integer "story_id", null: false
    t.integer "parent_quest_id"
    t.string "title", null: false
    t.text "premise", null: false
    t.string "status", default: "open", null: false
    t.boolean "contributes", default: true, null: false
    t.string "origin", default: "seeded", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_quest_id"], name: "index_quests_on_parent_quest_id"
    t.index ["story_id", "title"], name: "index_quests_on_story_id_and_title", unique: true
    t.index ["story_id"], name: "index_quests_on_story_id"
  end

  create_table "races", force: :cascade do |t|
    t.integer "universe_id", null: false
    t.string "name", null: false
    t.text "description", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "monstrous", default: false, null: false
    t.index ["universe_id", "name"], name: "index_races_on_universe_id_and_name", unique: true
    t.index ["universe_id"], name: "index_races_on_universe_id"
  end

  create_table "refused_lines", force: :cascade do |t|
    t.text "typed", null: false
    t.json "state", null: false
    t.json "answers"
    t.json "reading", null: false
    t.float "act_confidence"
    t.float "thing_confidence"
    t.json "refusal", null: false
    t.string "place"
    t.string "weights"
    t.integer "playthrough_id"
    t.integer "location_id"
    t.string "status", default: "new", null: false
    t.json "label"
    t.datetime "labelled_at"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_refused_lines_on_status"
  end

  create_table "relay_receipts", force: :cascade do |t|
    t.integer "player_id", null: false
    t.string "route", null: false
    t.string "model", null: false
    t.boolean "stream", default: false, null: false
    t.string "status", default: "open", null: false
    t.decimal "reserved_usd", precision: 12, scale: 6, null: false
    t.decimal "cost_usd", precision: 12, scale: 6
    t.string "cost_source"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.integer "upstream_status"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "created_at"], name: "index_relay_receipts_on_player_id_and_created_at"
    t.index ["player_id", "status"], name: "index_relay_receipts_on_player_id_and_status"
    t.index ["player_id"], name: "index_relay_receipts_on_player_id"
  end

  create_table "ruby_llm_batches", force: :cascade do |t|
    t.string "provider_batch_id", null: false
    t.string "provider", null: false
    t.string "status", null: false
    t.string "raw_status"
    t.boolean "completed", default: false, null: false
    t.string "chat_type"
    t.string "batch_protocol"
    t.json "chat_ids", default: []
    t.json "request_counts"
    t.json "reported_cost"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "provider_batch_id"], name: "index_ruby_llm_batches_on_provider_and_provider_batch_id", unique: true
    t.index ["status"], name: "index_ruby_llm_batches_on_status"
  end

  create_table "ruby_llm_models", force: :cascade do |t|
    t.string "model_id", null: false
    t.string "name", null: false
    t.string "provider", null: false
    t.string "family"
    t.datetime "model_created_at"
    t.integer "context_window"
    t.integer "max_output_tokens"
    t.date "knowledge_cutoff"
    t.json "modalities", default: {}
    t.json "capabilities", default: []
    t.json "pricing", default: {}
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "unlisted_at"
    t.index ["family"], name: "index_ruby_llm_models_on_family"
    t.index ["provider", "model_id"], name: "index_ruby_llm_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_ruby_llm_models_on_provider"
  end

  create_table "ruby_llm_tool_calls", force: :cascade do |t|
    t.integer "message_id", null: false
    t.string "tool_call_id", null: false
    t.string "name", null: false
    t.json "arguments", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "message_type", null: false
    t.string "result_type"
    t.integer "result_id"
    t.text "thought_signature"
    t.string "approval"
    t.boolean "remote", default: false, null: false
    t.index ["message_type", "message_id"], name: "index_ruby_llm_tool_calls_on_message_type_and_message_id"
    t.index ["name"], name: "index_ruby_llm_tool_calls_on_name"
    t.index ["result_type", "result_id"], name: "index_ruby_llm_tool_calls_on_result_type_and_result_id"
    t.index ["tool_call_id"], name: "index_ruby_llm_tool_calls_on_tool_call_id", unique: true
  end

  create_table "ruby_llm_usages", force: :cascade do |t|
    t.string "chat_type", null: false
    t.integer "chat_id", null: false
    t.string "message_type"
    t.integer "message_id"
    t.string "operation", null: false
    t.string "provider", null: false
    t.string "model", null: false
    t.string "status", null: false
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.integer "cache_read_tokens"
    t.integer "cache_write_tokens"
    t.integer "thinking_tokens"
    t.decimal "input_cost", precision: 16, scale: 10
    t.decimal "output_cost", precision: 16, scale: 10
    t.decimal "cache_read_cost", precision: 16, scale: 10
    t.decimal "cache_write_cost", precision: 16, scale: 10
    t.decimal "thinking_cost", precision: 16, scale: 10
    t.decimal "total_cost", precision: 16, scale: 10
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "latency_ms"
    t.index ["chat_type", "chat_id"], name: "index_ruby_llm_usages_on_chat_type_and_chat_id"
    t.index ["message_type", "message_id"], name: "index_ruby_llm_usages_on_message_type_and_message_id"
    t.index ["status"], name: "index_ruby_llm_usages_on_status"
    t.check_constraint "operation IN ('chat', 'embedding', 'moderation', 'image', 'speech', 'transcription', 'ocr', 'rerank')"
    t.check_constraint "status IN ('pending', 'succeeded', 'failed', 'cancelled')"
  end

  create_table "ruby_llm_v2_backfills", id: false, force: :cascade do |t|
    t.string "task", null: false
    t.integer "last_id"
    t.boolean "completed", default: false, null: false
    t.index ["task"], name: "index_ruby_llm_v2_backfills_on_task", unique: true
  end

  create_table "scenes", force: :cascade do |t|
    t.integer "story_id", null: false
    t.integer "location_id", null: false
    t.integer "previous_scene_id"
    t.text "description"
    t.datetime "story_timestamp"
    t.text "summary"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_opening", default: false, null: false
    t.text "typed"
    t.string "resolved_action"
    t.string "acted_on_type"
    t.integer "acted_on_id"
    t.string "resolved_by"
    t.boolean "engine_fallback", default: false, null: false
    t.text "engine_fact"
    t.index ["acted_on_type", "acted_on_id"], name: "index_scenes_on_acted_on"
    t.index ["location_id"], name: "index_scenes_on_location_id"
    t.index ["previous_scene_id"], name: "index_scenes_on_previous_scene_id"
    t.index ["story_id", "is_opening"], name: "index_scenes_on_story_id_and_is_opening"
    t.index ["story_id", "resolved_action"], name: "index_scenes_on_story_id_and_resolved_action"
    t.index ["story_id", "story_timestamp"], name: "index_scenes_on_story_id_and_story_timestamp"
    t.index ["story_id"], name: "index_scenes_on_story_id"
  end

  create_table "stories", force: :cascade do |t|
    t.string "title"
    t.string "genre"
    t.text "preface"
    t.text "summary"
    t.datetime "start_time"
    t.integer "universe_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "generation_snapshot"
    t.integer "people_limit"
    t.integer "things_limit"
    t.index ["universe_id"], name: "index_stories_on_universe_id"
  end

  create_table "system_one_receipts", force: :cascade do |t|
    t.integer "player_id"
    t.integer "playthrough_id"
    t.string "purpose"
    t.string "transport"
    t.decimal "cost_usd", precision: 12, scale: 6, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cost_source", default: "estimated", null: false
    t.integer "latency_ms"
    t.index ["player_id", "created_at"], name: "index_system_one_receipts_on_player_id_and_created_at"
    t.index ["player_id"], name: "index_system_one_receipts_on_player_id"
    t.index ["playthrough_id"], name: "index_system_one_receipts_on_playthrough_id"
  end

  create_table "universes", force: :cascade do |t|
    t.text "physics"
    t.text "technology"
    t.text "weapons"
    t.text "civilizations"
    t.text "geographies"
    t.text "history"
    t.text "economics"
    t.text "politics"
    t.text "religion"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "gravity"
    t.string "carrying"
  end

  create_table "world_events", force: :cascade do |t|
    t.integer "world_mechanic_id"
    t.integer "story_id", null: false
    t.datetime "occurred_at", null: false
    t.text "summary", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source", null: false
    t.integer "playthrough_id"
    t.datetime "scheduled_for"
    t.datetime "fired_at"
    t.index ["playthrough_id"], name: "index_world_events_on_playthrough_id"
    t.index ["story_id", "occurred_at"], name: "index_world_events_on_story_id_and_occurred_at"
    t.index ["story_id", "scheduled_for"], name: "index_world_events_on_story_id_and_scheduled_for"
    t.index ["story_id"], name: "index_world_events_on_story_id"
    t.index ["world_mechanic_id"], name: "index_world_events_on_world_mechanic_id"
  end

  create_table "world_mechanics", force: :cascade do |t|
    t.integer "story_id", null: false
    t.string "name", null: false
    t.string "kind", null: false
    t.string "cadence", null: false
    t.text "description"
    t.datetime "last_run_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["story_id", "name"], name: "index_world_mechanics_on_story_id_and_name", unique: true
    t.index ["story_id"], name: "index_world_mechanics_on_story_id"
  end

  add_foreign_key "characters", "locations"
  add_foreign_key "characters", "races"
  add_foreign_key "characters", "stories"
  add_foreign_key "chats", "characters"
  add_foreign_key "chats", "players"
  add_foreign_key "chats", "playthroughs"
  add_foreign_key "chats", "ruby_llm_models"
  add_foreign_key "interactions", "characters"
  add_foreign_key "interactions", "locations"
  add_foreign_key "interactions", "scenes"
  add_foreign_key "items", "characters"
  add_foreign_key "items", "locations"
  add_foreign_key "items", "playthroughs"
  add_foreign_key "lab_exits_judgements", "lab_exits_vantages", column: "vantage_id"
  add_foreign_key "lab_exits_samples", "lab_exits_vantages", column: "vantage_id"
  add_foreign_key "lab_realization_samples", "lab_realization_kinds", column: "kind_id"
  add_foreign_key "location_connections", "items", column: "key_template_id", on_delete: :nullify
  add_foreign_key "location_connections", "locations"
  add_foreign_key "location_connections", "locations", column: "connected_location_id"
  add_foreign_key "locations", "locations", column: "parent_location_id"
  add_foreign_key "locations", "stories"
  add_foreign_key "locations_world_events", "locations"
  add_foreign_key "locations_world_events", "world_events"
  add_foreign_key "messages", "chats"
  add_foreign_key "messages", "ruby_llm_models", column: "model_id"
  add_foreign_key "messages", "scenes"
  add_foreign_key "playthrough_beats", "playthroughs"
  add_foreign_key "playthrough_beats", "quest_steps"
  add_foreign_key "playthrough_blows", "characters", column: "attacker_id"
  add_foreign_key "playthrough_blows", "characters", column: "target_id"
  add_foreign_key "playthrough_blows", "locations"
  add_foreign_key "playthrough_blows", "playthroughs"
  add_foreign_key "playthrough_blows", "scenes"
  add_foreign_key "playthrough_commands", "playthroughs"
  add_foreign_key "playthrough_commands", "scenes", column: "result_scene_id"
  add_foreign_key "playthrough_drifts", "locations"
  add_foreign_key "playthrough_drifts", "playthroughs"
  add_foreign_key "playthrough_drifts", "scenes"
  add_foreign_key "playthrough_due_endings", "playthroughs"
  add_foreign_key "playthrough_due_endings", "quest_outcomes"
  add_foreign_key "playthrough_endings", "playthroughs"
  add_foreign_key "playthrough_endings", "quest_outcomes"
  add_foreign_key "playthrough_feedbacks", "playthroughs"
  add_foreign_key "playthrough_feedbacks", "scenes"
  add_foreign_key "playthrough_npc_states", "characters"
  add_foreign_key "playthrough_npc_states", "locations"
  add_foreign_key "playthrough_npc_states", "playthroughs"
  add_foreign_key "playthrough_overreaches", "locations"
  add_foreign_key "playthrough_overreaches", "playthroughs"
  add_foreign_key "playthrough_overreaches", "scenes"
  add_foreign_key "playthrough_paragraphs", "playthroughs"
  add_foreign_key "playthrough_paragraphs", "scenes"
  add_foreign_key "playthrough_passages", "items", column: "opened_by_item_id", on_delete: :nullify
  add_foreign_key "playthrough_passages", "location_connections", on_delete: :cascade
  add_foreign_key "playthrough_passages", "playthroughs", on_delete: :cascade
  add_foreign_key "playthrough_tolls", "characters"
  add_foreign_key "playthrough_tolls", "location_connections"
  add_foreign_key "playthrough_tolls", "locations"
  add_foreign_key "playthrough_tolls", "playthroughs"
  add_foreign_key "playthrough_tolls", "scenes"
  add_foreign_key "playthrough_turn_events", "playthrough_commands"
  add_foreign_key "playthrough_vitals", "characters"
  add_foreign_key "playthrough_vitals", "playthroughs"
  add_foreign_key "playthrough_volitions", "characters"
  add_foreign_key "playthrough_volitions", "locations"
  add_foreign_key "playthrough_volitions", "playthroughs"
  add_foreign_key "playthrough_volitions", "scenes"
  add_foreign_key "playthroughs", "characters"
  add_foreign_key "playthroughs", "locations", column: "current_location_id"
  add_foreign_key "playthroughs", "players"
  add_foreign_key "playthroughs", "scenes", column: "current_scene_id"
  add_foreign_key "playthroughs", "stories"
  add_foreign_key "quest_outcomes", "quests"
  add_foreign_key "quest_steps", "quests"
  add_foreign_key "quests", "quests", column: "parent_quest_id"
  add_foreign_key "quests", "stories"
  add_foreign_key "races", "universes"
  add_foreign_key "relay_receipts", "players"
  add_foreign_key "scenes", "locations"
  add_foreign_key "scenes", "scenes", column: "previous_scene_id"
  add_foreign_key "scenes", "stories"
  add_foreign_key "stories", "universes"
  add_foreign_key "system_one_receipts", "players"
  add_foreign_key "system_one_receipts", "playthroughs"
  add_foreign_key "world_events", "stories"
  add_foreign_key "world_events", "world_mechanics"
  add_foreign_key "world_mechanics", "stories"
end
