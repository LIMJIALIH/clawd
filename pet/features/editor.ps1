# --------------------------------------------------------- the outfit maker --
# Paint an outfit on Clawd's grid, pixel by pixel, in front of or behind the body. Saved to
# outfits-custom.json and listed under Outfit → Mine.

$CustomOutfitsFile = Join-Path $petDir 'outfits-custom.json'
$EDIT_ROWS = -5..4
$EDIT_COLS = -2..17
$EDIT_CELL = 20
$EDIT_PALETTE = @('#1E1E24', '#F4FAFF', '#C8343F', '#E67E22', '#F2C230', '#2E9E6B', '#5BC0EB', '#3A6EA5', '#8E44AD', '#E91E63', '#7A4E2D', '#9AA3AD')

function Load-CustomOutfits {
  try {
    $j = [IO.File]::ReadAllText($CustomOutfitsFile) | ConvertFrom-Json
    foreach ($p in $j.PSObject.Properties) {
      $o = $p.Value
      $OUTFITS[$p.Name] = @{
        label = [string]$o.label; group = 'Mine'
        front = @($o.front | ForEach-Object { , @($_) })
        back = @($o.back | ForEach-Object { , @($_) })
      }
    }
  } catch { }
}

function Save-CustomOutfit([string]$key, [string]$label, $front, $back) {
  $all = [ordered]@{}
  try {
    $j = [IO.File]::ReadAllText($CustomOutfitsFile) | ConvertFrom-Json
    foreach ($p in $j.PSObject.Properties) { $all[$p.Name] = $p.Value }
  } catch { }
  $all[$key] = [ordered]@{ label = $label; front = @($front); back = @($back) }
  try { [IO.File]::WriteAllText($CustomOutfitsFile, ($all | ConvertTo-Json -Depth 5)) } catch { }
  $OUTFITS[$key] = @{ label = $label; group = 'Mine'; front = @($front); back = @($back) }
}

function Show-OutfitEditor {
  $ED = @{ color = $EDIT_PALETTE[2]; layer = 'front'; cells = @{} }
  $w = [Windows.Window]::new()
  $w.Title = 'Clawd''s outfit maker'
  $w.SizeToContent = 'WidthAndHeight'; $w.ResizeMode = 'NoResize'; $w.Topmost = $true
  $w.WindowStartupLocation = 'CenterScreen'
  $panel = [Windows.Controls.StackPanel]::new(); $panel.Margin = '12'

  $hint = [Windows.Controls.TextBlock]::new()
  $hint.Text = 'Click or drag to paint, right-click to erase. Clawd''s body is the faint orange.'
  $hint.Margin = '0,0,0,8'
  [void]$panel.Children.Add($hint)

  # The grid, with Clawd underneath for reference.
  $grid = [Windows.Controls.Canvas]::new()
  $grid.Width = $EDIT_COLS.Count * $EDIT_CELL; $grid.Height = $EDIT_ROWS.Count * $EDIT_CELL
  $grid.Background = [Windows.Media.Brushes]::White
  $ghost = @(@(2, 0, 12, 4), @(0, 2, 2, 1), @(14, 2, 2, 1), @(3, 4, 1, 1), @(5, 4, 1, 1), @(10, 4, 1, 1), @(12, 4, 1, 1))
  foreach ($gp in $ghost) {
    $r = [Windows.Shapes.Rectangle]::new()
    $r.Width = $gp[2] * $EDIT_CELL; $r.Height = $gp[3] * $EDIT_CELL
    $r.Fill = $ORANGE; $r.Opacity = 0.3; $r.IsHitTestVisible = $false
    [Windows.Controls.Canvas]::SetLeft($r, ($gp[0] - $EDIT_COLS[0]) * $EDIT_CELL)
    [Windows.Controls.Canvas]::SetTop($r, ($gp[1] - $EDIT_ROWS[0]) * $EDIT_CELL)
    [void]$grid.Children.Add($r)
  }
  foreach ($row in $EDIT_ROWS) {
    foreach ($col in $EDIT_COLS) {
      $cell = [Windows.Shapes.Rectangle]::new()
      $cell.Width = $EDIT_CELL; $cell.Height = $EDIT_CELL
      $cell.Fill = [Windows.Media.Brushes]::Transparent
      $cell.Stroke = [Windows.Media.BrushConverter]::new().ConvertFromString('#22000000'); $cell.StrokeThickness = 0.5
      $cell.Tag = "$col,$row"
      [Windows.Controls.Canvas]::SetLeft($cell, ($col - $EDIT_COLS[0]) * $EDIT_CELL)
      [Windows.Controls.Canvas]::SetTop($cell, ($row - $EDIT_ROWS[0]) * $EDIT_CELL)
      [void]$grid.Children.Add($cell)
    }
  }
  $paint = {
    param($sender, $e)
    $cell = $e.OriginalSource
    if ($cell -isnot [Windows.Shapes.Rectangle] -or -not $cell.Tag) { return }
    if ($e.RightButton -eq 'Pressed') {
      $ED.cells.Remove($cell.Tag); $cell.Fill = [Windows.Media.Brushes]::Transparent
    } elseif ($e.LeftButton -eq 'Pressed') {
      $ED.cells[$cell.Tag] = @{ color = $ED.color; layer = $ED.layer }
      $b = [Windows.Media.BrushConverter]::new().ConvertFromString($ED.color)
      if ($ED.layer -eq 'back') { $b.Opacity = 0.55 }
      $cell.Fill = $b
    }
  }.GetNewClosure()
  $grid.Add_MouseDown($paint)
  $grid.Add_MouseMove($paint)
  [void]$panel.Children.Add($grid)

  # The palette and the layer.
  $tools = [Windows.Controls.WrapPanel]::new(); $tools.Margin = '0,8,0,0'
  foreach ($hex in $EDIT_PALETTE) {
    $sw = [Windows.Controls.Button]::new()
    $sw.Width = 24; $sw.Height = 24; $sw.Margin = '0,0,4,4'
    $sw.Background = [Windows.Media.BrushConverter]::new().ConvertFromString($hex)
    $sw.Tag = $hex
    $sw.Add_Click({ param($sender) $ED.color = $sender.Tag }.GetNewClosure())
    [void]$tools.Children.Add($sw)
  }
  $layer = [Windows.Controls.CheckBox]::new()
  $layer.Content = 'Paint behind the body (capes, wings)'; $layer.Margin = '8,4,0,0'
  $layer.Add_Click({ param($sender) if ($sender.IsChecked) { $ED.layer = 'back' } else { $ED.layer = 'front' } }.GetNewClosure())
  [void]$tools.Children.Add($layer)
  [void]$panel.Children.Add($tools)

  $row2 = [Windows.Controls.StackPanel]::new(); $row2.Orientation = 'Horizontal'; $row2.Margin = '0,8,0,0'
  $nameBox = [Windows.Controls.TextBox]::new(); $nameBox.Width = 220; $nameBox.Text = 'My outfit'; $nameBox.Margin = '0,0,8,0'
  $save = [Windows.Controls.Button]::new(); $save.Content = 'Save & wear'; $save.Width = 100
  $save.Add_Click({ $w.Tag = @{ name = $nameBox.Text; cells = $ED.cells }; $w.DialogResult = $true }.GetNewClosure())
  [void]$row2.Children.Add($nameBox); [void]$row2.Children.Add($save)
  [void]$panel.Children.Add($row2)
  $w.Content = $panel

  if (-not $w.ShowDialog() -or -not $w.Tag) { return }
  $front = @(); $back = @()
  foreach ($k in $w.Tag.cells.Keys) {
    $c = $k -split ','
    $piece = @([double]$c[0], [double]$c[1], 1, 1, $w.Tag.cells[$k].color)
    if ($w.Tag.cells[$k].layer -eq 'back') { $back += , $piece } else { $front += , $piece }
  }
  if (-not ($front.Count + $back.Count)) { Say 'Nothing painted, nothing saved.' 2 $true; return }
  $label = $w.Tag.name.Trim(); if (-not $label) { $label = 'My outfit' }
  $key = 'mine-' + (($label.ToLower() -replace '[^a-z0-9]+', '-').Trim('-'))
  Save-CustomOutfit $key $label $front $back
  Wear-Outfit $key $true
  Show-Off
}

Load-CustomOutfits
$OUTFIT_GROUPS = @($OUTFIT_GROUPS) + @('Mine')
