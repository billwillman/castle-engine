{
  Copyright 2002-2010 Michalis Kamburelis.

  This file is part of "Kambi VRML game engine".

  "Kambi VRML game engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Kambi VRML game engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ 2D float rectangles (TArea).
  Main use is to detect in which
  2D area on the screen user clicked with mouse.

  The usual use is to create many areas and add them to DefaultAreas manager.
  Then you can query DefaultAreas.FindArea to find an area containing
  given X, Y position.

  This is not a terribly interesting unit. In fact, it's
  a very trivial, short and boring unit. The idea was that
  I may eventually implement other area shapes (not only rectangles),
  more intelligent area searching code and generally use this as a basis
  for simple 2D widgetset in OpenGL. Then things here would get
  more interesting.

  For now, it's used e.g. by OpenGL menu in GLMenu unit.
}

unit Areas;

interface

{$define read_interface}

uses KambiUtils, SysUtils;

type
  TArea = record
    X0, Y0, Width, Height: Single;
  end;
  PArea = ^TArea;

  TDynArrayItem_1 = TArea;
  PDynArrayItem_1 = PArea;
  {$define DYNARRAY_1_IS_STRUCT}
  {$I dynarray_1.inc}

  TDynAreaArray = class(TDynArray_1)
  public

    { FindArea returns index of the area that contains point (X, Y).

      @italic(It returns the index of the @bold(last) area, that is:
      it searches from the end of the list.) This way the areas added
      later by Add method are treated as being on top of previous
      areas, which is more intuitive.

      Returns -1 if not found. }
    function FindArea(const X, Y: Single): integer;
  end;

const
  EmptyArea: TArea = (X0: 0; Y0: 0; Width: -1; Height: -1);

function Area(const X0, Y0, Width, Height: Single): TArea;

function AreaCorners(X0, Y0, X1, Y1: Single): TArea;

{ TODO: unused anywhere, so untested. }
{ }
function AreasSum(const Area1, Area2: TArea): TArea;

function PointInArea(const X, Y: Single; const Area: TArea): boolean;

var
  DefaultAreas: TDynAreaArray;

{$undef read_interface}

implementation

{$define read_implementation}
{$I dynarray_1.inc}

{ TDynAreaArray -------------------------------------------------------------- }

function TDynAreaArray.FindArea(const X, Y: Single): integer;
begin
  for Result := High downto 0 do
    if PointInArea(X, Y, Items[Result]) then
      Exit;
  Result := -1;
end;

{ global funcs --------------------------------------------------------------- }

function Area(const X0, Y0, Width, Height: Single): TArea;
begin
  Result.X0 := X0;
  Result.Y0 := Y0;
  Result.Width := Width;
  Result.Height := Height;
end;

function AreaCorners(X0, Y0, X1, Y1: Single): TArea;
begin
  OrderUp(X0, X1);
  OrderUp(Y0, Y1);
  Result.X0 := X0;
  Result.Y0 := Y0;
  Result.Width := X1 - X0 + 1;
  Result.Height := Y1 - Y0 + 1;
end;

function AreasSum(const Area1, Area2: TArea): TArea;
begin
  Result.X0 := Min(Area1.X0, Area2.X0);
  Result.Y0 := Min(Area1.Y0, Area2.Y0);
  Result.Width := Max(
    Area1.X0 + Area1.Width - Result.X0,
    Area2.X0 + Area2.Width - Result.X0);
  Result.Height := Max(
    Area1.Y0 + Area1.Height - Result.Y0,
    Area2.Y0 + Area2.Height - Result.Y0);
end;

function PointInArea(const X, Y: Single; const Area: TArea): boolean;
begin
  Result := (X >= Area.X0) and (X <= Area.X0 + Area.Width) and
            (Y >= Area.Y0) and (Y <= Area.Y0 + Area.Height);
end;

{ initialization / finalization ---------------------------------------------- }

initialization
  DefaultAreas := TDynAreaArray.Create;
finalization
  FreeAndNil(DefaultAreas);
end.
