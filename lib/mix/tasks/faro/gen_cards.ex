defmodule Mix.Tasks.Faro.GenCards do
  use Mix.Task

  @shortdoc "Generate SVG playing card assets into priv/static/images/cards/"

  @suits [:spades, :hearts, :diamonds, :clubs]

  @cream "#FEFCE8"
  @border "#D6D3D1"
  @dark "#292524"
  @red "#B91C1C"
  @back_green "#14532D"
  @back_amber "#92400E"

  def run(_args) do
    out_dir = "priv/static/images/cards"
    File.mkdir_p!(out_dir)

    for suit <- @suits, rank <- 1..13 do
      File.write!(Path.join(out_dir, card_file(rank, suit)), card_svg(rank, suit))
    end

    File.write!(Path.join(out_dir, "back.svg"), back_svg())
    Mix.shell().info("Generated 53 SVG cards in #{out_dir}/")
  end

  # ---- Naming ----

  defp card_file(rank, suit), do: "#{rank_name(rank)}_#{suit}.svg"

  defp rank_name(1), do: "ace"
  defp rank_name(11), do: "jack"
  defp rank_name(12), do: "queen"
  defp rank_name(13), do: "king"
  defp rank_name(n), do: to_string(n)

  defp rank_label(1), do: "A"
  defp rank_label(11), do: "J"
  defp rank_label(12), do: "Q"
  defp rank_label(13), do: "K"
  defp rank_label(n), do: to_string(n)

  defp suit_symbol(:spades), do: "♠"
  defp suit_symbol(:hearts), do: "♥"
  defp suit_symbol(:diamonds), do: "♦"
  defp suit_symbol(:clubs), do: "♣"

  defp pip_color(:spades), do: @dark
  defp pip_color(:clubs), do: @dark
  defp pip_color(:hearts), do: @red
  defp pip_color(:diamonds), do: @red

  # ---- Card SVG ----

  defp card_svg(rank, suit) do
    c = pip_color(suit)
    sym = suit_symbol(suit)
    lbl = rank_label(rank)

    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 280">
      <rect width="200" height="280" rx="12" fill="#{@cream}" stroke="#{@border}" stroke-width="1.5"/>
      #{corners(lbl, sym, c)}
      #{center(rank, suit, c)}
    </svg>
    """
  end

  # Corner labels: top-left, then a 180° rotation around card centre for bottom-right.
  defp corners(lbl, sym, c) do
    f = "Georgia,serif"

    """
    <text x="15" y="28" font-family="#{f}" font-size="22" font-weight="bold" fill="#{c}" text-anchor="middle">#{lbl}</text>
    <text x="15" y="46" font-family="#{f}" font-size="16" fill="#{c}" text-anchor="middle">#{sym}</text>
    <g transform="rotate(180,100,140)">
      <text x="15" y="28" font-family="#{f}" font-size="22" font-weight="bold" fill="#{c}" text-anchor="middle">#{lbl}</text>
      <text x="15" y="46" font-family="#{f}" font-size="16" fill="#{c}" text-anchor="middle">#{sym}</text>
    </g>
    """
  end

  defp center(1, suit, c) do
    ~s[<text x="100" y="148" font-family="Georgia,serif" font-size="90" fill="#{c}" text-anchor="middle" dominant-baseline="central">#{suit_symbol(suit)}</text>]
  end

  defp center(rank, suit, c) when rank in 11..13 do
    lbl = rank_label(rank)
    sym = suit_symbol(suit)

    """
    <rect x="58" y="80" width="84" height="120" rx="6" fill="none" stroke="#{c}" stroke-width="1" opacity="0.25"/>
    <text x="100" y="136" font-family="Georgia,serif" font-size="62" font-weight="bold" fill="#{c}" text-anchor="middle" dominant-baseline="central" opacity="0.9">#{lbl}</text>
    <text x="100" y="180" font-family="Georgia,serif" font-size="22" fill="#{c}" text-anchor="middle" dominant-baseline="central">#{sym}</text>
    """
  end

  defp center(rank, suit, c) do
    sym = suit_symbol(suit)

    Enum.map_join(pip_positions(rank), "\n", fn {x, y, inv} ->
      xform = if inv, do: ~s[ transform="rotate(180,#{x},#{y})"], else: ""

      ~s[<text x="#{x}" y="#{y}" font-family="Georgia,serif" font-size="26" fill="#{c}" text-anchor="middle" dominant-baseline="central"#{xform}>#{sym}</text>]
    end)
  end

  # Standard pip positions: {x, y, inverted?} in 200×280 card space.
  # Two columns at x=67 and x=133, centre column at x=100.
  # Pip area runs from y≈90 to y≈190.
  defp pip_positions(2), do: [{100, 90, false}, {100, 190, true}]
  defp pip_positions(3), do: [{100, 90, false}, {100, 140, false}, {100, 190, true}]

  defp pip_positions(4),
    do: [{67, 90, false}, {133, 90, false}, {67, 190, true}, {133, 190, true}]

  defp pip_positions(5),
    do: [{67, 90, false}, {133, 90, false}, {100, 140, false}, {67, 190, true}, {133, 190, true}]

  defp pip_positions(6),
    do: [
      {67, 90, false},
      {133, 90, false},
      {67, 140, false},
      {133, 140, false},
      {67, 190, true},
      {133, 190, true}
    ]

  defp pip_positions(7),
    do: [
      {67, 90, false},
      {133, 90, false},
      {100, 112, false},
      {67, 140, false},
      {133, 140, false},
      {67, 190, true},
      {133, 190, true}
    ]

  defp pip_positions(8),
    do: [
      {67, 90, false},
      {133, 90, false},
      {100, 112, false},
      {67, 140, false},
      {133, 140, false},
      {100, 168, true},
      {67, 190, true},
      {133, 190, true}
    ]

  defp pip_positions(9),
    do: [
      {67, 90, false},
      {133, 90, false},
      {67, 115, false},
      {133, 115, false},
      {100, 140, false},
      {67, 165, true},
      {133, 165, true},
      {67, 190, true},
      {133, 190, true}
    ]

  defp pip_positions(10),
    do: [
      {67, 90, false},
      {133, 90, false},
      {100, 104, false},
      {67, 115, false},
      {133, 115, false},
      {67, 165, true},
      {133, 165, true},
      {100, 176, true},
      {67, 190, true},
      {133, 190, true}
    ]

  # ---- Back SVG ----

  defp back_svg do
    diamonds =
      for(row <- 0..11, col <- 0..8, do: {row, col})
      |> Enum.map_join("\n", fn {row, col} ->
        x = 16 + col * 22
        y = 18 + row * 24

        ~s[<path d="M#{x},#{y - 7} L#{x + 7},#{y} L#{x},#{y + 7} L#{x - 7},#{y} Z" fill="none" stroke="#{@back_amber}" stroke-width="0.7" opacity="0.4"/>]
      end)

    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 280">
      <rect width="200" height="280" rx="12" fill="#{@back_green}" stroke="#{@back_amber}" stroke-width="2"/>
      <rect x="10" y="10" width="180" height="260" rx="8" fill="none" stroke="#78350F" stroke-width="1"/>
      <clipPath id="c"><rect x="12" y="12" width="176" height="256" rx="7"/></clipPath>
      <g clip-path="url(#c)">
    #{diamonds}
      </g>
      <text x="100" y="140" font-size="44" fill="#D97706" text-anchor="middle" dominant-baseline="central" opacity="0.75">✦</text>
    </svg>
    """
  end
end
