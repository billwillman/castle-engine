{
  Copyright 2015, 2016 Tomasz Wojtyś

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ TMX files processing unit. Based on Tiled v0.17. }
unit CastleTiledMap;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DOM, XMLRead, base64, zstream, CastleGenericLists, CastleVectors,
  CastleColors, CastleUtils, CastleURIUtils, CastleXMLUtils, CastleLog;

type
  TProperty = record
    { The name of the property. }
    Name: string;
    { The value of the property. }
    Value: string;
    { The type of the property. Can be string (default), int, float, bool, color
      or file (since 0.16, with color and file added in 0.17). }
    _type: string;
  end;

  { List of properties. }
  TProperties = specialize TGenericStructList<TProperty>;

  TEncodingType = (ET_None, ET_Base64, ET_CSV);
  TCompressionType = (CT_None, CT_GZip, CT_ZLib);

  { Binary data definition. }
  TData = record
    { The encoding used to encode the tile layer data. When used, it can be
      "base64" and "csv" at the moment. }
    Encoding: TEncodingType;
    { The compression used to compress the tile layer data. Tiled Qt supports
      "gzip" and "zlib". }
    Compression: TCompressionType;
    { Binary data. Uncompressed and decoded. }
    Data: array of Cardinal;
  end;

  { Image definition. }
  TImage = record
    { Used for embedded images, in combination with a data child element.
      Valid values are file extensions like png, gif, jpg, bmp, etc. (since 0.9) }
    Format: string;
    { The reference to the tileset image file (Tiled supports most common
      image formats). }
    Source: string;
    { Defines a specific color that is treated as transparent (example value:
      "#FF00FF" for magenta). Up until Tiled 0.12, this value is written out
      without a # but this is planned to change. }
    Trans: TCastleColorRGB;
    { The image width in pixels (optional, used for tile index correction when
      the image changes). }
    Width: Cardinal;
    { The image height in pixels (optional). }
    Height: Cardinal;
    //todo: data
  end;

  { Single frame of animation. }
  TFrame = record
    { The local ID of a tile within the parent tileset. }
    TileId: Cardinal;
    { How long (in milliseconds) this frame should be displayed before advancing
      to the next frame. }
    Duration: Cardinal;
  end;

  { Contains a list of animation frames.
    As of Tiled 0.10, each tile can have exactly one animation associated with it.
    In the future, there could be support for multiple named animations on a tile. }
  TAnimation = specialize TGenericStructList<TFrame>;

  TTile = record //todo: tile loading
    { The local tile ID within its tileset. }
    Id: Cardinal;
    { Defines the terrain type of each corner of the tile, given as
      comma-separated indexes in the terrain types array in the order top-left,
      top-right, bottom-left, bottom-right. Leaving out a value means that corner
      has no terrain. (optional) (since 0.9) }
    Terrain: string; // todo: terrain type definition
    { A percentage indicating the probability that this tile is chosen when it
      competes with others while editing with the terrain tool. (optional) (since 0.9) }
    Probability: Single;
    Properties: TProperties;
    Image: TImage;
    //todo: ObjectGroup since 0.10
    Animation: TAnimation; //todo: animation loading
  end;

  { Tiles list. }
  TTiles = specialize TGenericStructList<TTile>;

  TTerrain = record
    { The name of the terrain type. }
    Name: string;
    { The local tile-id of the tile that represents the terrain visually. }
    Tile: Cardinal;
    Properties: TProperties;
  end;

  { This element defines an array of terrain types, which can be referenced from
    the terrain attribute of the tile element. }
  TTerrainTypes = specialize TGenericStructList<TTerrain>;

  PTileset = ^TTileset;
  { Tileset definition. }
  TTileset = record
    { The first global tile ID of this tileset (this global ID maps to the first
    tile in this tileset). }
    FirstGID: Cardinal;
    { If this tileset is stored in an external TSX (Tile Set XML) file, this
      attribute refers to that file. That TSX file has the same structure as the
      <tileset> element described here. (There is the firstgid attribute missing
      and this source attribute is also not there. These two attributes
      are kept in the TMX map, since they are map specific.) }
    Source: string;
    { The name of this tileset. }
    Name: string;
    { The (maximum) width of the tiles in this tileset. }
    TileWidth: Cardinal;
    { The (maximum) height of the tiles in this tileset. }
    TileHeight: Cardinal;
    { The spacing in pixels between the tiles in this tileset (applies to the
      tileset image). }
    Spacing: Cardinal;
    { The margin around the tiles in this tileset (applies to the tileset image). }
    Margin: Cardinal;
    { The number of tiles in this tileset (since 0.13) }
    TileCount: Cardinal;
    { The number of tile columns in the tileset. For image collection tilesets
    it is editable and is used when displaying the tileset. (since 0.15) }
    Columns: Cardinal;
    { This element is used to specify an offset in pixels, to be applied when
      drawing a tile from the related tileset. When not present, no offset is applied. }
    TileOffset: TVector2Integer;
    Properties: TProperties;
    Image: TImage;
    Tiles: TTiles; // todo: Tiles loading
    TerrainTypes: TTerrainTypes; //todo: loading TerrainTypes
    { Pointer to image of tileset. Used by renderer. Not a part of file format. }
    ImageData: Pointer;
  end;

  { List of tilesets. }
  TTilesets = specialize TGenericStructList<TTileset>;

  TObjectsDrawOrder = (ODO_Index, ODO_TopDown);

  TTileObjectPrimitive = (TOP_Ellipse, TOP_Poligon, TOP_PolyLine);

  { Object definition. }
  TTiledObject = record
    { Unique ID of the object. Each object that is placed on a map gets
      a unique id. Even if an object was deleted, no object gets the same ID.
      Can not be changed in Tiled Qt. (since Tiled 0.11) }
    Id: Integer;
    { The name of the object. An arbitrary string. }
    Name: string;
    { The type of the object. An arbitrary string. }
    Type_: string;
    { The x coordinate of the object in pixels. }
    X: Single;
    { The y coordinate of the object in pixels. }
    Y: Single;
    { The width of the object in pixels (defaults to 0). }
    Width: Single;
    { The height of the object in pixels (defaults to 0). }
    Height: Single;
    { The rotation of the object in degrees clockwise (defaults to 0). (since 0.10) }
    Rotation: Single;
    { An reference to a tile (optional). }
    GId: Integer;
    { Whether the object is shown (1) or hidden (0). Defaults to 1. (since 0.9) }
    Visible: Boolean;
    Properties: TProperties;
    { List of points for poligon and poliline. }
    Points: TVector2SingleList;
    Primitive: TTileObjectPrimitive;
    Image: TImage;
  end;

  TTiledObjects = specialize TGenericStructList<TTiledObject>;
  TLayerType = (LT_Layer, LT_ObjectGroup, LT_ImageLayer);

  PLayer = ^TLayer;
  { Layer definition. Internally we treat "object group" as normal layer. }
  TLayer = record
    { The name of the layer. }
    Name: string;
    { The opacity of the layer as a value from 0 to 1. Defaults to 1. }
    Opacity: Single;
    { Whether the layer is shown (1) or hidden (0). Defaults to 1. }
    Visible: Boolean;
    { Rendering offset for this layer in pixels. Defaults to 0. (since 0.14). }
    OffsetX: Integer;
    { Rendering offset for this layer in pixels. Defaults to 0. (since 0.14). }
    OffsetY: Integer;
    Properties: TProperties;
    Data: TData;
    { If True then the layer will be treated as object group instead of normal layer. }
    IsLayerAnObjectGroup: Boolean;
    { The color used to display the objects in this group. }
    Color: TCastleColorRGB;
    { The x coordinate of the object group in tiles. Defaults to 0 and can no longer be changed in Tiled Qt. }
    X: Integer; //todo: deprecated since 0.15
    { The y coordinate of the object group in tiles. Defaults to 0 and can no longer be changed in Tiled Qt. }
    Y: Integer; //todo: deprecated since 0.15
    { The width of the object group in tiles. Meaningless. }
    Width: Integer;
    { The height of the object group in tiles. Meaningless. }
    Height: Integer;
    { Whether the objects are drawn according to the order of appearance
      ("index") or sorted by their y-coordinate ("topdown"). Defaults to "topdown". }
    DrawOrder: TObjectsDrawOrder;
    Objects: TTiledObjects;
    LayerType: TLayerType;
    { Used by ImageLayer. }
    Image: TImage;
  end;

  { List of layers. }
  TLayers = specialize TGenericStructList<TLayer>;

  TMapOrientation = (MO_Orthogonal, MO_Isometric, MO_Staggered);
  TMapRenderOrder = (MRO_RightDown, MRO_RightUp, MRO_LeftDown, MRO_LeftUp);

  { Loading and manipulating "Tiled" map files (http://mapeditor.org).
    Based on Tiled version 0.14. }

	{ TTiledMap }

  TTiledMap = class
  private
    { Map stuff. }
    { The TMX format version, generally 1.0. }
    FVersion: string;
    FOrientation: TMapOrientation;
    FWidth: Cardinal;
    FHeight: Cardinal;
    FTileWidth: Cardinal;
    FTileHeight: Cardinal;
    { The background color of the map. (since 0.9, optional) }
    FBackgroundColor: TCastleColorRGB;
    FRenderOrder: TMapRenderOrder;
    FDataPath: string;

    procedure LoadTileset(Element: TDOMElement);
    { TSX file loading. }
    procedure LoadTilesetFromFile(const AFileName: string);
    procedure LoadProperty(Element: TDOMElement; var AProperty: TProperty);
    procedure LoadProperties(Element: TDOMElement; var AProperties: TProperties);
    procedure LoadImage(Element: TDOMElement; var AImage: TImage);
    procedure LoadLayer(Element: TDOMElement);
    procedure LoadObjectGroup(Element: TDOMElement);
    procedure LoadTiledObject(Element: TDOMElement; var ATiledObject: TTiledObject);
    procedure LoadImageLayer(Element: TDOMElement);
    procedure LoadData(Element: TDOMElement; var AData: TData);
  private
    FTilesets: TTilesets;
    FProperties: TProperties;
    FLayers: TLayers;
    procedure LoadTMXFile(AURL: string);
  public
    property Layers: TLayers read FLayers;
    { Map orientation. Tiled supports "orthogonal", "isometric" and "staggered"
      (since 0.9) at the moment. }
    property Orientation: TMapOrientation read FOrientation;
    property Properties: TProperties read FProperties;
    property Tilesets: TTilesets read FTilesets;
    { The map width in tiles. }
    property Width: Cardinal read FWidth;
    { The map height in tiles. }
    property Height: Cardinal read FHeight;
    { The order in which tiles on tile layers are rendered. Valid values are
      right-down (the default), right-up, left-down and left-up. In all cases,
      the map is drawn row-by-row. (since 0.10, but only supported for orthogonal
      maps at the moment) }
    { The width of a tile. }
    property TileWidth: Cardinal read FTileWidth;
    { The height of a tile. }
    property TileHeight: Cardinal read FTileHeight;
    property RenderOrder: TMapRenderOrder read FRenderOrder;
    { @param(AURL) - URL to TMX file. }
    constructor Create(AURL: string);
    destructor Destroy; override;
    { Returns the pointer to tileset that contain the global ID. }
    function GIDToTileset(const AGID: Cardinal): PTileSet;
  end;

implementation

procedure TTiledMap.LoadTileset(Element: TDOMElement);
var
  I: TXMLElementIterator;
  NewTileset: TTileset;
  TmpStr: string;
begin
  with NewTileset do
  begin
    TileOffset := ZeroVector2Integer;
    Properties := nil;
    if Element.AttributeString('firstgid', TmpStr) then
      FirstGID := StrToInt(TmpStr) else
        FirstGID := 1;
    if Element.AttributeString('source', TmpStr) then
    begin
      Source := TmpStr;
      WritelnLog('LoadTileset source', Source);
      LoadTilesetFromFile(Source);
      Exit;
    end;
    if Element.AttributeString('name', TmpStr) then
      Name := TmpStr;
    if Element.AttributeString('tilewidth', TmpStr) then
      TileWidth := StrToInt(TmpStr);
    if Element.AttributeString('tileheight', TmpStr) then
      TileHeight := StrToInt(TmpStr);
    if Element.AttributeString('spacing', TmpStr) then
      Spacing := StrToInt(TmpStr);
    if Element.AttributeString('margin', TmpStr) then
      Margin := StrToInt(TmpStr);
    if Element.AttributeString('tilecount', TmpStr) then
      TileCount := StrToInt(TmpStr) else
        TileCount := 0;
    if Element.AttributeString('columns', TmpStr) then
      Columns := StrToInt(TmpStr) else
        Columns := 0;
    WritelnLog('LoadTileset firstgid', IntToStr(FirstGID));
    WritelnLog('LoadTileset Name', Name);
    WritelnLog('LoadTileset TileWidth', IntToStr(TileWidth));
    WritelnLog('LoadTileset TileHeight', IntToStr(TileHeight));
    WritelnLog('LoadTileset Spacing', IntToStr(Spacing));
    WritelnLog('LoadTileset Margin', IntToStr(Margin));
    WritelnLog('LoadTileset TileCount', IntToStr(TileCount));
    WritelnLog('LoadTileset Columns', IntToStr(Columns));

    I := TXMLElementIterator.Create(Element);
    try
      while I.GetNext do
      begin
        WritelnLog('LoadTileset element', I.Current.TagName);
        case LowerCase(I.Current.TagName) of
          'tileoffset': begin
            TileOffset[0] := StrToInt(I.Current.GetAttribute('x'));
            TileOffset[1] := StrToInt(I.Current.GetAttribute('y'));
          end;
          'properties': LoadProperties(I.Current, Properties);
          'image': LoadImage(I.Current, Image);
        end;
      end;
    finally FreeAndNil(I) end;
  end;

  FTilesets.Add(NewTileset);
end;

procedure TTiledMap.LoadTilesetFromFile(const AFileName: string);
var
  Doc: TXMLDocument;
begin
  try
    URLReadXML(Doc, FDataPath + AFileName);

    Check(LowerCase(Doc.DocumentElement.TagName) = 'tileset',
      'Root element of TSX file must be <tileset>');
    LoadTileset(Doc.DocumentElement);

  finally
    FreeAndNil(Doc);
  end;
end;

procedure TTiledMap.LoadProperty(Element: TDOMElement;
  var AProperty: TProperty);
begin
  AProperty.Name := Element.GetAttribute('name');
  AProperty.Value := Element.GetAttribute('value');
  AProperty._type := Element.GetAttribute('type');
  WritelnLog('LoadProperty name', AProperty.Name);
  WritelnLog('LoadProperty value', AProperty.Value);
  WritelnLog('LoadProperty type', AProperty._type);
end;

procedure TTiledMap.LoadProperties(Element: TDOMElement;
  var AProperties: TProperties);
var
  I: TXMLElementIterator;
  NewProperty: TProperty;
begin
  I := TXMLElementIterator.Create(Element);
  try
    while I.GetNext do
    begin
      WritelnLog('LoadProperties element', I.Current.TagName);
      case LowerCase(I.Current.TagName) of
        'property':
        begin
          LoadProperty(I.Current, NewProperty);
          if not Assigned (AProperties) then
            AProperties := TProperties.Create;
          AProperties.Add(NewProperty);
        end;
      end;
    end;
  finally FreeAndNil(I) end;
end;

procedure TTiledMap.LoadImage(Element: TDOMElement; var AImage: TImage);
const
  DEFAULT_TRANS:TCastleColorRGB = ( 1.0, 0.0, 1.0); {Fuchsia}
begin
  with AImage do
  begin
    Format := Element.GetAttribute('format');
    Source := Element.GetAttribute('source');
    if Element.hasAttribute('trans') then
      Trans := HexToColorRGB(Element.GetAttribute('trans')) else //todo: if color in XML will be with "#" sign then it throws conversion error
        Trans := DEFAULT_TRANS;
    Width := StrToInt(Element.GetAttribute('width'));
    Height := StrToInt(Element.GetAttribute('height'));
    WritelnLog('LoadImage Format', Format);
    WritelnLog('LoadImage Source', Source);
    WritelnLog('LoadImage Trans', ColorRGBToHex(Trans));
    WritelnLog('LoadImage Width', IntToStr(Width));
    WritelnLog('LoadImage Height', IntToStr(Height));
  end;
  //todo: loading data element
end;

procedure TTiledMap.LoadLayer(Element: TDOMElement);
var
  I: TXMLElementIterator;
  NewLayer: TLayer;
  TmpStr: string;
begin
  with NewLayer do
  begin
    Properties := nil;
    Opacity := 1;
    Visible := True;
    OffsetX := 0;
    OffsetY := 0;
    LayerType := LT_Layer;
    Name := Element.GetAttribute('name');
    if Element.AttributeString('opacity', TmpStr) then
      Opacity := StrToFloat(TmpStr);
    if Element.GetAttribute('visible') = '0' then
      Visible := False;
    if Element.AttributeString('offsetx', TmpStr) then
      OffsetX := StrToInt(TmpStr);
    if Element.AttributeString('offsety', TmpStr) then
      OffsetY := StrToInt(TmpStr);
    WritelnLog('LoadTileset Name', Name);
    WritelnLog('LoadTileset Visible', BoolToStr(Visible, 'True', 'False'));
    WritelnLog('LoadTileset Opacity', FloatToStr(Opacity));
    WritelnLog('LoadTileset OffsetX', IntToStr(OffsetX));
    WritelnLog('LoadTileset OffsetY', IntToStr(OffsetY));

    I := TXMLElementIterator.Create(Element);
    try
      while I.GetNext do
      begin
        WritelnLog('LoadLayer element', I.Current.TagName);
        case LowerCase(I.Current.TagName) of
          'properties': LoadProperties(I.Current, Properties);
          'data': LoadData(I.Current, Data);
        end;
      end;
    finally FreeAndNil(I) end;
  end;

  FLayers.Add(NewLayer);
end;

procedure TTiledMap.LoadObjectGroup(Element: TDOMElement);
var
  I: TXMLElementIterator;
  NewLayer: TLayer;
  NewObject: TTiledObject;
  TmpStr: string;
begin
  with NewLayer do
  begin
    Properties := nil;
    Objects := nil;
    Opacity := 1;
    Visible := True;
    OffsetX := 0;
    OffsetY := 0;
    DrawOrder := ODO_TopDown;
    LayerType := LT_ObjectGroup;
    Name := Element.GetAttribute('name');
    if Element.AttributeString('opacity', TmpStr) then
      Opacity := StrToFloat(TmpStr);
    if Element.GetAttribute('visible') = '0' then
      Visible := False;
    if Element.AttributeString('offsetx', TmpStr) then
      OffsetX := StrToInt(TmpStr);
    if Element.AttributeString('offsety', TmpStr) then
      OffsetY := StrToInt(TmpStr);
    if Element.AttributeString('draworder', TmpStr) then
      case TmpStr of
        'index': DrawOrder := ODO_Index;
        'topdown': DrawOrder := ODO_TopDown;
      end;
    WritelnLog('LoadTileset Name', Name);
    WritelnLog('LoadTileset Visible', BoolToStr(Visible, 'True', 'False'));
    WritelnLog('LoadTileset Opacity', FloatToStr(Opacity));
    WritelnLog('LoadTileset OffsetX', IntToStr(OffsetX));
    WritelnLog('LoadTileset OffsetY', IntToStr(OffsetY));
  end;

  I := TXMLElementIterator.Create(Element);
  try
    while I.GetNext do
    begin
      WritelnLog('LoadObjectGroup element', I.Current.TagName);
      case LowerCase(I.Current.TagName) of
        'properties': LoadProperties(I.Current, NewLayer.Properties);
        'object': begin
          LoadTiledObject(I.Current, NewObject);
          if not Assigned(NewLayer.Objects) then
            NewLayer.Objects := TTiledObjects.Create;
          NewLayer.Objects.Add(NewObject);
        end;
      end;
    end;
  finally FreeAndNil(I) end;

  FLayers.Add(NewLayer);
end;

procedure TTiledMap.LoadTiledObject(Element: TDOMElement;
  var ATiledObject: TTiledObject);
var
  I: TXMLElementIterator;
  TmpStr: string;

  procedure ReadPoints(const PointsString: string; var PointsList: TVector2SingleList);
  const
    PointsSeparator = Char(' ');
    SinglePointSeparator = Char(',');
  var
    tmpChar, p: PChar;
    tmpChar2, p2: PChar;
    tmpPoint, tmpPoint2: string;
    VectorPoint: TVector2Single;
  begin
    if not Assigned(PointsList) then PointsList := TVector2SingleList.Create;
    p := PChar(PointsString);
    repeat
      tmpChar := StrPos(p, PointsSeparator);
      if tmpChar = nil then tmpChar := StrScan(p, #0);
      SetString(tmpPoint, p, tmpChar - p);
      p2 := PChar(tmpPoint);

      tmpChar2 := StrPos(p2, SinglePointSeparator);
      SetString(tmpPoint2, p2, tmpChar2 - p2);
      VectorPoint[0] := StrToFloat(tmpPoint2);
      p2 := tmpChar2 + 1;
      tmpChar2 := StrScan(p2, #0);
      SetString(tmpPoint2, p2, tmpChar2 - p2);
      VectorPoint[1] := StrToFloat(tmpPoint2);
      PointsList.Add(VectorPoint);

      p := tmpChar + 1;
    until tmpChar^ = #0;
  end;

begin
  with ATiledObject do
  begin
    Width := 0;
    Height := 0;
    Rotation := 0;
    Visible := True;
    Properties := nil;
    Points := nil;
    if Element.AttributeString('id', TmpStr) then
      Id := StrToInt(TmpStr);
    if Element.AttributeString('name', TmpStr) then
      Name := TmpStr;
    if Element.AttributeString('type', TmpStr) then
      Type_ := TmpStr;
    if Element.AttributeString('x', TmpStr) then
      X := StrToFloat(TmpStr);
    if Element.AttributeString('y', TmpStr) then
      Y := StrToFloat(TmpStr);
    if Element.AttributeString('width', TmpStr) then
      Width := StrToFloat(TmpStr);
    if Element.AttributeString('height', TmpStr) then
      Height := StrToFloat(TmpStr);
    if Element.AttributeString('rotation', TmpStr) then
      Rotation := StrToFloat(TmpStr);
    if Element.AttributeString('gid', TmpStr) then
      GId := StrToInt(TmpStr);
    if Element.AttributeString('visible', TmpStr) then
      if TmpStr = '0' then
        Visible := False;

    I := TXMLElementIterator.Create(Element);
    try
      while I.GetNext do
      begin
        WritelnLog('LoadTiledObject element', I.Current.TagName);
        case LowerCase(I.Current.TagName) of
          'properties': LoadProperties(I.Current, Properties);
          'ellipse': Primitive := TOP_Ellipse;
          'polygon': begin
            Primitive := TOP_Poligon;
            ReadPoints(I.Current.GetAttribute('points'), Points);
          end;
          'polyline': begin
            Primitive := TOP_PolyLine;
            ReadPoints(I.Current.GetAttribute('points'), Points);
          end;
          'image': LoadImage(I.Current, Image);
        end;
      end;
    finally FreeAndNil(I) end;
  end;
end;

procedure TTiledMap.LoadImageLayer(Element: TDOMElement);
var
  I: TXMLElementIterator;
  NewLayer: TLayer;
  TmpStr: string;
begin
  with NewLayer do
  begin
    Properties := nil;
    Opacity := 1;
    Visible := True;
    OffsetX := 0;
    OffsetY := 0;
    LayerType := LT_ImageLayer;
    Name := Element.GetAttribute('name');
    if Element.AttributeString('opacity', TmpStr) then
      Opacity := StrToFloat(TmpStr);
    if Element.GetAttribute('visible') = '0' then
      Visible := False;
    if Element.AttributeString('x', TmpStr) then
      X := StrToInt(TmpStr); //todo: deprecated since 0.15
    if Element.AttributeString('y', TmpStr) then
      Y := StrToInt(TmpStr); //todo: deprecated since 0.15
    if Element.AttributeString('offsetx', TmpStr) then
      OffsetX := StrToInt(TmpStr);
    if Element.AttributeString('offsety', TmpStr) then
      OffsetY := StrToInt(TmpStr);
    WritelnLog('LoadTileset Name', Name);
    WritelnLog('LoadTileset Visible', BoolToStr(Visible, 'True', 'False'));
    WritelnLog('LoadTileset Opacity', FloatToStr(Opacity));
    WritelnLog('LoadTileset X', IntToStr(X));
    WritelnLog('LoadTileset Y', IntToStr(Y));
    WritelnLog('LoadTileset OffsetX', IntToStr(OffsetX));
    WritelnLog('LoadTileset OffsetY', IntToStr(OffsetY));

    I := TXMLElementIterator.Create(Element);
    try
      while I.GetNext do
      begin
        WritelnLog('LoadImageLayer element', I.Current.TagName);
        case LowerCase(I.Current.TagName) of
          'properties': LoadProperties(I.Current, NewLayer.Properties);
          'image': LoadImage(I.Current, Image);
        end;
      end;
    finally FreeAndNil(I) end;
  end;

  FLayers.Add(NewLayer);
end;

procedure TTiledMap.LoadData(Element: TDOMElement; var AData: TData);
const
  BufferSize = 16;
  CSVDataSeparator = Char(',');
var
  I: TXMLElementIterator;
  TmpStr, RawData: string;
  Decompressor, Decoder: TStream;
  Buffer: array[0..BufferSize-1] of Cardinal;
  DataCount, DataLength: Longint;
  CSVItem: string;
  tmpChar, p: PChar;
  CSVDataCount: Cardinal;
  UsePlainXML: Boolean;
  j: Integer;
begin
  UsePlainXML := False;
  with AData do
  begin
    Encoding := ET_None;
    Compression := CT_None;
    if Element.AttributeString('encoding', TmpStr) then
      case TmpStr of
        'base64': Encoding := ET_Base64;
        'csv': Encoding := ET_CSV;
      end;
    if Element.AttributeString('compression', TmpStr) then
      case TmpStr of
        'gzip': Compression := CT_Gzip;
        'zlib': Compression := CT_ZLib;
      end;

    if (Encoding = ET_None) and (Compression = CT_None) then
    begin
      UsePlainXML := True;
    end else begin
      RawData := Element.TextContent;
      WritelnLog('LoadData RawData', RawData);
      case Encoding of
        ET_Base64: begin
          Decoder := TBase64DecodingStream.Create(TStringStream.Create(RawData));
        end;
        ET_CSV: begin
          // remove EOLs
          RawData := StringReplace(RawData, #10, '', [rfReplaceAll]);
          RawData := StringReplace(RawData, #13, '', [rfReplaceAll]);
          // count data
          CSVDataCount := 0;
          tmpChar := StrScan(PChar(RawData), CSVDataSeparator);;
          while tmpChar <> nil do
          begin
            Inc(CSVDataCount);
            tmpChar := StrScan(StrPos(tmpChar, CSVDataSeparator) + 1, CSVDataSeparator);
          end;
          // read data
          SetLength(Data, CSVDataCount + 1);
          p := PChar(RawData);
          DataCount := 0;
          repeat
            tmpChar := StrPos(p, CSVDataSeparator);
            if tmpChar = nil then tmpChar := StrScan(p, #0);
            SetString(CSVItem, p, tmpChar - p);
            Data[DataCount] := StrToInt(CSVItem);
            Inc(DataCount);
            p := tmpChar + 1;
          until tmpChar^ = #0;
        end;
      end;
      case Compression of
        CT_Gzip: WritelnLog('LoadData', 'Gzip format not implemented'); //todo: gzip reading
        CT_ZLib: begin
          try
            Decompressor := TDecompressionStream.Create(Decoder);
            repeat
              DataCount := Decompressor.Read(Buffer, BufferSize * SizeOf(Cardinal));
              DataLength := Length(Data);
              SetLength(Data, DataLength+(DataCount div SizeOf(Cardinal)));
              if DataCount > 0 then // becouse if DataCount=0 then ERangeCheck error
                Move(Buffer, Data[DataLength], DataCount);
            until DataCount < SizeOf(Buffer);
            {TmpStr := '';
            for j := Low(Data) to High(Data) do
              TmpStr := TmpStr + ',' + IntToStr(Data[j]);
            WriteLnLog('LoadData Data', TmpStr);  }

          finally
            Decompressor.Free;
          end;
        end;
        CT_None: begin
          // Base64 only
          if Encoding = ET_Base64 then
            repeat
              DataCount := Decoder.Read(Buffer, BufferSize * SizeOf(Cardinal));
              DataLength := Length(Data);
              SetLength(Data, DataLength+(DataCount div SizeOf(Cardinal)));
              if DataCount > 0 then // becouse if DataCount=0 then ERangeCheck error
                Move(Buffer, Data[DataLength], DataCount);
            until DataCount < SizeOf(Buffer);
        end;
      end;
    end;

    I := TXMLElementIterator.Create(Element);
    try
      while I.GetNext do
      begin
        WritelnLog('LoadData element', I.Current.TagName);
        case LowerCase(I.Current.TagName) of
          'tile': if UsePlainXML then
          begin
            SetLength(Data, Length(Data)+1);
            Data[High(Data)] := StrToInt(I.Current.GetAttribute('gid'));
          end;
        end;
      end;
    finally FreeAndNil(I) end;
  end;
end;

procedure TTiledMap.LoadTMXFile(AURL: string);
var
  Doc: TXMLDocument;
  TmpStr: string;
  I: TXMLElementIterator;
begin
  try
    URLReadXML(Doc, AURL);

    // Parse map attributes
    Check(LowerCase(Doc.DocumentElement.TagName) = 'map',
      'Root element of TMX file must be <map>');
    if Doc.DocumentElement.AttributeString('version', TmpStr) then
      FVersion := TmpStr;
    if Doc.DocumentElement.AttributeString('orientation', TmpStr) then
      case TmpStr of
        'orthogonal': FOrientation := MO_Orthogonal;
        'isometric': FOrientation := MO_Isometric;
        'staggered': FOrientation := MO_Staggered;
      end;
    if Doc.DocumentElement.AttributeString('width', TmpStr) then
      FWidth := StrToInt(TmpStr);
    if Doc.DocumentElement.AttributeString('height', TmpStr) then
      FHeight := StrToInt(TmpStr);
    if Doc.DocumentElement.AttributeString('tilewidth', TmpStr) then
      FTileWidth := StrToInt(TmpStr);
    if Doc.DocumentElement.AttributeString('tileheight', TmpStr) then
      FTileHeight := StrToInt(TmpStr);
    if Doc.DocumentElement.AttributeString('backgroundcolor', TmpStr) then
      FBackgroundColor := HexToColorRGB(TmpStr);
    if Doc.DocumentElement.AttributeString('renderorder', TmpStr) then
      case TmpStr of
        'right-down': FRenderOrder := MRO_RightDown;
        'right-up': FRenderOrder := MRO_RightUp;
        'left-down': FRenderOrder := MRO_LeftDown;
        'left-up': FRenderOrder := MRO_LeftUp;
      end;
    // Parse map childrens
    I := TXMLElementIterator.Create(Doc.DocumentElement);
    try
      while I.GetNext do
      begin
        WritelnLog('LoadTMXFile element', I.Current.TagName);
        case LowerCase(I.Current.TagName) of
          'tileset': LoadTileset(I.Current);
          'layer': LoadLayer(I.Current);
          'objectgroup': LoadObjectGroup(I.Current);
          'imagelayer': LoadImageLayer(I.Current);
          'properties': LoadProperties(I.Current, FProperties);
        end;
      end;
    finally FreeAndNil(I) end;
  finally
    FreeAndNil(Doc);
  end;
end;

constructor TTiledMap.Create(AURL: string);
begin
  FTilesets := TTilesets.Create;
  FProperties := TProperties.Create;
  FLayers := TLayers.Create;
  FDataPath := ExtractURIPath(AURL);

  //Load TMX
  LoadTMXFile(AURL);
end;

destructor TTiledMap.Destroy;
begin
  FreeAndNil(FTilesets);
  FreeAndNil(FProperties);
  FreeAndNil(FLayers);
  inherited Destroy;
end;

function TTiledMap.GIDToTileset(const AGID: Cardinal): PTileSet;
var
  i: Integer;
begin
  //todo: test gidtotileset
  for i := 0 to FTilesets.Count - 1 do
    if FTilesets.Items[i].FirstGID > AGID then
    begin
      Result := FTilesets.Ptr(i-1);
      Break;
		end;
  Result := FTilesets.Ptr(FTilesets.Count - 1);
end;


end.
