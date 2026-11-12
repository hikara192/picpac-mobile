enum EditorTool {
  frame,

  light,

  warmth,

  style,

  rotate,

  replace,

  swap,

  background;

  bool get needsPhoto =>
      this == frame ||
      this == light ||
      this == warmth ||
      this == rotate ||
      this == replace ||
      this == swap;
}
