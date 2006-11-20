{
  Copyright 2004-2006 Michalis Kamburelis.

  This file is part of "Kambi's OpenGL Pascal units".

  "Kambi's OpenGL Pascal units" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "Kambi's OpenGL Pascal units" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "Kambi's OpenGL Pascal units"; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

{ A simple program using GLWindow.
  Demonstrates the use of MainMenu in TGLWindow.

  Shows menu, submenus, menus with keyboard shortcuts, checked menu items,
  radio menu items, adding menus at runtime, using menu mnemonics. }

program MenuTest;

uses VectorMath, OpenGLh, GLWindow, GLW_Demo, KambiGLUtils,
  GLWinMessages;

var
  { Some state variables that determine what will be drawn.
    Just to show that menu commands actually work... }
  CurrentColor: Integer = 0;
  RectShape: boolean;
  Filled: boolean = true;
  MoveX: Single = 0.0;
  MoveY: Single = 0.0;
  MenuHorizLeft, MenuHorizMiddle, MenuHorizRight: TMenuItemRadio;

const
  Colors: array[0..6]of TVector3Byte =
  ( ($FF, 0, 0),
    (0, $FF, 0),
    (0, 0, $FF),
    ($FF, $FF, 0),
    ($FF, $FF, $FF),
    ($8F, $8F, $8F),
    (0, 0, 0)
  );

procedure Draw(glwin: TGLWindow);
begin
 glClear(GL_COLOR_BUFFER_BIT);
 glColorv(Colors[CurrentColor]);

 if Filled then
  glPolygonMode(GL_FRONT_AND_BACK, GL_FILL) else
  glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);

 glLoadIdentity;
 glTranslatef(MoveX, MoveY, 0);

 if RectShape then
  glRectf(-0.5, -0.5, 0.5, 0.5) else
 begin
  glBegin(GL_TRIANGLES);
    glVertex2f(-0.5, -0.5);
    glVertex2f(0.5, -0.5);
    glVertex2f(0, 0.5);
  glEnd;
 end;
end;

procedure Resize(glwin: TGLWindow);
begin
 glViewport(0, 0, glwin.Width, glwin.Height);
 ProjectionGLOrtho(-1, 1, -1, 1);
end;

var
  ChangeableMenu: TMenu;

procedure MenuCommand(glwin: TGLWindow; Item: TMenuItem);

  procedure ChangeChecked(Item: TMenuItemRadio);
  begin
    Item.Checked := MessageYesNo(Glw, 'Should menu item "' +
      SRemoveMnemonics(Item.Caption) + '" be checked ?', taLeft);
    if Item.Checked then
      case Item.IntData of
        25: MoveX := -0.5;
        26: MoveX := 0.0;
        27: MoveX := 0.5;
      end;
  end;

var M: TMenu;
begin
 Writeln('You clicked menu item "', SRemoveMnemonics(Item.Caption),
   '" with SmallId ', Item.SmallId);
 case Item.IntData of
  0..High(Colors): CurrentColor := Item.IntData;
  10: RectShape := true;
  11: RectShape := false;
  20: glwin.Close;

  21: MoveY := +0.5;
  22: MoveY :=  0.0;
  23: MoveY := -0.5;

  25..27: ChangeChecked(Item as TMenuItemRadio);

  31: Filled := not Filled;
  40: glwin.MainMenu.Append(TMenuItem.Create('New item', -1));
  41: begin
       M := TMenu.Create('New submenu');
       M.Append(TMenuItem.Create('_One', -1));
       M.Append(TMenuItem.Create('_Two', -1));
       ChangeableMenu.Append(M);
      end;
  42: ChangeableMenu.Append(TMenuItem.Create('New item', -1));
  else Exit;
 end;
 glw.PostRedisplay;
end;

var
  M, M2: TMenu;

  { Helper variables for setting up radio items }
  Radio: TMenuItemRadio;
  RadioGroup: TMenuItemRadioGroup;
begin
 { create menu }
 glw.MainMenu := TMenu.Create('Main menu');
 M := TMenu.Create('_File');
   M.Append(TMenuItem.Create('_Exit', 20));
   glw.MainMenu.Append(M);
 M := TMenu.Create('_Color');
   M.Append(TMenuItem.Create('_Red', 0));
   M.Append(TMenuItem.Create('_Green', 1));
   M.Append(TMenuItem.Create('_Blue', 2));
   M.Append(TMenuItem.Create('_Yellow', 3));
   M.Append(TMenuSeparator.Create);
   M.Append(TMenuItem.Create('_White', 4));
   M.Append(TMenuItem.Create('Gr_ay', 5));
   M.Append(TMenuItem.Create('B_lack', 6));
   glw.MainMenu.Append(M);

 M := TMenu.Create('_Placement');

   { Radio menu items test }

   { First radio test: simple use AutoCheckToggle := true }
   Radio := TMenuItemRadio.Create('_Top', 21, false, true);
   RadioGroup := Radio.Group; { First: get Group }
   M.Append(Radio);
   Radio := TMenuItemRadio.Create('_Middle', 22, true, true);
   Radio.Group := RadioGroup;
   M.Append(Radio);
   Radio := TMenuItemRadio.Create('_Bottom', 23, false, true);
   Radio.Group := RadioGroup;
   M.Append(Radio);

   { Second radio test: use without AutoCheckToggle := true,
     we will explicitly set Checked. }
   M.Append(TMenuSeparator.Create);
   MenuHorizLeft := TMenuItemRadio.Create('_Left', 25, false, false);
   RadioGroup := MenuHorizLeft.Group;
   M.Append(MenuHorizLeft);
   MenuHorizMiddle := TMenuItemRadio.Create('M_iddle', 26, true, false);
   MenuHorizMiddle.Group := RadioGroup;
   M.Append(MenuHorizMiddle);
   MenuHorizRight := TMenuItemRadio.Create('_Right', 27, true, false);
   MenuHorizRight.Group := RadioGroup;
   M.Append(MenuHorizRight);

   glw.MainMenu.Append(M);

 M := TMenu.Create('_Shape');
   M.Append(TMenuItemChecked.Create('_Filled', 31, Filled, true));
   M2 := TMenu.Create('_More options');
     M2.Append(TMenuItem.Create('_foo with underscore : __', 101));
     M2.Append(TMenuItem.Create('_bar', 102));
     M.Append(M2);
   M.Append(TMenuItem.Create('_Rectangle', 10, 'r'));
   M.Append(TMenuItem.Create('_Triangle',  11, 't'));
   glw.MainMenu.Append(M);
 M := TMenu.Create('_Change menu');
 ChangeableMenu := M;
   M.Append(TMenuItem.Create('Create new _main menu item', 40));
   M.Append(TMenuItem.Create('Create new _submenu here',   41));
   M.Append(TMenuItem.Create('Create new menu _item here', 42));
   M.Append(TMenuSeparator.Create);
   glw.MainMenu.Append(M);

 glw.OnMenuCommand := @MenuCommand;
 glw.OnResize := @Resize;
 glw.ParseParameters;
 glw.Width := 300;
 glw.Height := 300;
 glw.DepthBufferBits := 0;
 glw.InitLoop('Test Menu', @Draw);
end.