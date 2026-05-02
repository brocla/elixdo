# To find more emoji to add to this file:
#   emojipedia.org — search by name, copy the character
#   On Windows: Win + . opens the emoji picker
#   On Mac: Cmd + Ctrl + Space


defmodule Elixdo.Emoji do
  @moduledoc "Converts :shortcode: patterns to emoji characters."

  @map %{
    "church" => "⛪",
    "thumbsup" => "👍",
    "thumbsdown" => "👎",
    "+1" => "👍",
    "-1" => "👎",
    "smile" => "😄",
    "grin" => "😁",
    "laughing" => "😆",
    "joy" => "😂",
    "wink" => "😉",
    "blush" => "😊",
    "heart" => "❤️",
    "heart_eyes" => "😍",
    "ok_hand" => "👌",
    "raised_hands" => "🙌",
    "clap" => "👏",
    "wave" => "👋",
    "point_right" => "👉",
    "point_left" => "👈",
    "point_up" => "☝️",
    "point_down" => "👇",
    "fire" => "🔥",
    "star" => "⭐",
    "check" => "✅",
    "white_check_mark" => "✅",
    "x" => "❌",
    "warning" => "⚠️",
    "tada" => "🎉",
    "rocket" => "🚀",
    "bulb" => "💡",
    "memo" => "📝",
    "calendar" => "📅",
    "clock" => "🕐",
    "money" => "💰",
    "moneybag" => "💰",
    "phone" => "📱",
    "email" => "📧",
    "house" => "🏠",
    "car" => "🚗",
    "dog" => "🐶",
    "cat" => "🐱",
    "pizza" => "🍕",
    "coffee" => "☕",
    "lock" => "🔒",
    "key" => "🔑",
    "wrench" => "🔧",
    "hammer" => "🔨",
    "question" => "❓",
    "exclamation" => "❗",
    "eyes" => "👀",
    "muscle" => "💪",
    "seedling" => "🌱",
    "tree" => "🌳",
    "sun" => "☀️",
    "snowflake" => "❄️",
    "zap" => "⚡",
    "umbrella" => "☂️"
  }

  @doc "Replace :shortcode: patterns in text with emoji characters."
  def convert(text) do
    Regex.replace(~r/:([a-z0-9_+\-]+):/, text, fn _, code ->
      Map.get(@map, code, ":#{code}:")
    end)
  end
end
