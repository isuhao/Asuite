{
Copyright (C) 2006-2015 Matteo Salvi

Website: http://www.salvadorsoftware.com/

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
}

unit Forms.ScanFolder;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, VirtualTrees, ComCtrls, DKLang, Vcl.Mask,
  JvExMask, JvToolEdit;

type
  TfrmScanFolder = class(TForm)
    btnScan: TButton;
    btnCancel: TButton;
    pnlScan: TPanel;
    grpFileTypes: TGroupBox;
    btnTypesReplace: TButton;
    btnTypesDelete: TButton;
    lxTypes: TListBox;
    btnTypesAdd: TButton;
    edtTypes: TEdit;
    grpExclude: TGroupBox;
    lxExclude: TListBox;
    edtExclude: TEdit;
    btnExcludeAdd: TButton;
    btnExcludeReplace: TButton;
    btnExcludeDelete: TButton;
    grpPath: TGroupBox;
    cbSubfolders: TCheckBox;
    lbFolderPath: TLabel;
    DKLanguageController1: TDKLanguageController;
    edtFolderPath: TJvDirectoryEdit;
    cbFlat: TCheckBox;
    procedure btnScanClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnTypesAddClick(Sender: TObject);
    procedure btnTypesReplaceClick(Sender: TObject);
    procedure btnTypesDeleteClick(Sender: TObject);
    procedure btnExcludeAddClick(Sender: TObject);
    procedure btnExcludeReplaceClick(Sender: TObject);
    procedure btnExcludeDeleteClick(Sender: TObject);
  private
    { Private declarations }
    procedure PopulateStringList(ListBox: TListBox; StringList: TStringList);
    procedure PopulateListBox(ListBox: TListBox; StringList: TStringList);
    procedure DoScanFolder(Sender: TBaseVirtualTree;FolderPath: string;
                           ParentNode: PVirtualNode;ProgressDialog: TForm);
    procedure RunScanFolder(Tree: TBaseVirtualTree;TempPath: string; ChildNode: PVirtualNode);
  public
    { Public declarations }
    class procedure Execute(AOwner: TComponent);
  end;

var
  frmScanFolder: TfrmScanFolder;

implementation

uses
  Utility.Misc, NodeDataTypes.Custom, AppConfig.Main, Kernel.Enumerations,
  VirtualTree.Methods, Utility.System, NodeDataTypes.Files, NodeDataTypes.Base;

{$R *.dfm}

procedure TfrmScanFolder.btnCancelClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmScanFolder.btnExcludeAddClick(Sender: TObject);
begin
  lxExclude.Items.Add(LowerCase(edtExclude.Text));
  edtExclude.Clear;
end;

procedure TfrmScanFolder.btnExcludeDeleteClick(Sender: TObject);
begin
  if (lxExclude.ItemIndex <> -1) then
  begin
    lxExclude.Items.Delete(lxExclude.ItemIndex);
    lxExclude.ItemIndex := -1;
  end;
end;

procedure TfrmScanFolder.PopulateListBox(ListBox: TListBox;
  StringList: TStringList);
var
  I: Integer;
begin
  ListBox.Clear;
  for I := 0 to StringList.Count - 1 do
    if StringList[I] <> '' then
      ListBox.Items.Add(LowerCase(StringList[I]));
end;

procedure TfrmScanFolder.PopulateStringList(ListBox: TListBox; StringList: TStringList);
var
  I: Integer;
begin
  StringList.Clear;
  for I := 0 to ListBox.Count - 1 do
    StringList.Add(LowerCase(ListBox.Items[I]));
end;

procedure TfrmScanFolder.DoScanFolder(Sender: TBaseVirtualTree;
  FolderPath: string; ParentNode: PVirtualNode;
  ProgressDialog: TForm);
var
  SearchRec     : TSearchRec;
  ChildNode     : PVirtualNode;
  ChildNodeData : TvCustomRealNodeData;
  TempShortName, PathTemp, sFileExt : String;
  ProgressBar   : TProgressBar;
begin
  //TODO: Rewrite this code (see AddChildNodeEx)
  ProgressBar   := TProgressBar(ProgressDialog.FindComponent('Progress'));
  if FindFirst(FolderPath + '*.*', faAnyFile, SearchRec) = 0 then
  begin
    repeat
      ChildNode     := nil;
      ChildNodeData := nil;
      TempShortName := LowerCase(SearchRec.Name);
      sFileExt := ExtractFileExt(TempShortName);
      //Absolute path->relative path
      PathTemp := Config.Paths.AbsoluteToRelative(FolderPath + SearchRec.Name);
      //Add node in vstlist
      if ((SearchRec.Name <> '.') and (SearchRec.Name <> '..')) and
         (((SearchRec.Attr and faDirectory) = (faDirectory)) or ((Config.ScanFolderFileTypes.IndexOf(sFileExt) <> -1))) then
      begin
        //Extract file name without extension (.ext)
        TempShortName := ChangeFileExt(TempShortName,'');
        if (Config.ScanFolderExcludeNames.IndexOf(TempShortName) = -1) then
        begin
          if ((SearchRec.Attr and faDirectory) = (faDirectory)) and (Config.ScanFolderSubFolders) then
          begin
            ChildNode := Sender.AddChild(ParentNode, TVirtualTreeMethods.Create.CreateNodeData(vtdtCategory));
            ChildNodeData := TvCustomRealNodeData(TVirtualTreeMethods.Create.GetNodeItemData(ChildNode, Sender));
            //Dialog
            ProgressBar.Position := ProgressBar.Position + 1;
            ProgressDialog.Update;
            DoScanFolder(Sender, IncludeTrailingBackslash(FolderPath + SearchRec.Name), ChildNode, ProgressDialog);
          end
          else
            if (SearchRec.Attr <> faDirectory) and (Config.ScanFolderFileTypes.IndexOf(sFileExt) <> -1) then
            begin
              ChildNode := Sender.AddChild(ParentNode, TVirtualTreeMethods.Create.CreateNodeData(vtdtFile));
              ChildNodeData := TvCustomRealNodeData(TVirtualTreeMethods.Create.GetNodeItemData(ChildNode, Sender));
              if Assigned(ChildNodeData) then
                TvFileNodeData(ChildNodeData).PathFile := PathTemp;
            end;
          if Assigned(ChildNodeData) then
          begin
            ChildNodeData.SetPointerNode(ChildNode);
            ChildNodeData.Name  := TempShortName;
            if (ChildNode.ChildCount = 0) And (ChildNodeData.DataType = vtdtCategory) then
              Sender.DeleteNode(ChildNode);
          end;
        end;
      end;
    until FindNext(SearchRec) <> 0;
  end;
  FindClose(SearchRec);
end;

class procedure TfrmScanFolder.Execute(AOwner: TComponent);
var
  frm: TfrmScanFolder;
begin
  frm := TfrmScanFolder.Create(AOwner);
  try
    frm.ShowModal;
  finally
    frm.Free;
  end;
end;

procedure TfrmScanFolder.RunScanFolder(Tree: TBaseVirtualTree;TempPath: string; ChildNode: PVirtualNode);
var
  Dialog: TForm;
begin
  //Run scan
  Dialog := CreateDialogProgressBar(DKLangConstW('msgScanningProgress'), Config.Paths.GetNumberSubFolders(TempPath));
  Tree.BeginUpdate;
  try
    DoScanFolder(Tree, TempPath, ChildNode, Dialog);
  finally
    Tree.EndUpdate;
    Dialog.Free;
    Self.Close;
  end;
end;

procedure TfrmScanFolder.btnExcludeReplaceClick(Sender: TObject);
begin
  if (lxExclude.ItemIndex <> -1) and (lxExclude.Count > 0)  then
  begin
    lxExclude.Items.Delete(lxExclude.ItemIndex);
    lxExclude.Items.Insert(lxExclude.ItemIndex,LowerCase(edtExclude.Text));
    lxExclude.ItemIndex := -1;
  end;
end;

procedure TfrmScanFolder.btnScanClick(Sender: TObject);
var
  ChildNode : PVirtualNode;
  ChildNodeData : TvBaseNodeData;
  TempPath, sName : String;
begin
  //TODO: Rewrite this code (see AddChildNodeEx and maybe use a thread)
  if edtFolderPath.Text <> '' then
    TempPath := IncludeTrailingBackslash(edtFolderPath.Text);
  //Check if user insert a valid path
  if TempPath <> '' then
  begin
    if (DirectoryExists(TempPath)) then
    begin
      //Add parent node
      ChildNode := TVirtualTreeMethods.Create.AddChildNodeEx(Config.MainTree, Config.MainTree.GetFirstSelected, amInsertAfter, vtdtCategory);
      ChildNodeData := TVirtualTreeMethods.Create.GetNodeItemData(ChildNode, Config.MainTree);
//      ImagesDM.GetNodeImageIndex(TvCustomRealNodeData(ChildNodeData), isAny);
      //Extract directory name and use it as node name (else use TempPath as name)
      sName := ExtractDirectoryName(TempPath);
      if sName <> '' then
        ChildNodeData.Name := sName
      else
        ChildNodeData.Name := TempPath;
      RunScanFolder(Config.MainTree, TempPath, ChildNode);
    end
    else
      ShowMessageEx(DKLangConstW('msgFolderNotFound'));
  end
  else
    ShowMessageEx(DKLangConstW('msgErrEmptyPath'));
end;

procedure TfrmScanFolder.btnTypesAddClick(Sender: TObject);
begin
  lxTypes.Items.Add(LowerCase(edtTypes.Text));
  edtTypes.Clear;
end;

procedure TfrmScanFolder.btnTypesDeleteClick(Sender: TObject);
begin
  if (lxTypes.ItemIndex <> -1) then
  begin
    lxTypes.Items.Delete(lxTypes.ItemIndex);
    lxTypes.ItemIndex := -1;
  end;
end;

procedure TfrmScanFolder.btnTypesReplaceClick(Sender: TObject);
begin
  if (lxTypes.ItemIndex <> -1) and (lxTypes.Count > 0)  then
  begin
    lxTypes.Items.Delete(lxTypes.ItemIndex);
    lxTypes.Items.Insert(lxTypes.ItemIndex,LowerCase(edtTypes.Text));
    lxTypes.ItemIndex := -1;
  end;
end;

procedure TfrmScanFolder.FormCreate(Sender: TObject);
begin
  if DirectoryExists(Config.ScanFolderLastPath) then
    edtFolderPath.Text := Config.ScanFolderLastPath
  else
    edtFolderPath.Text := Config.Paths.SuitePathWorking;
  cbSubfolders.Checked   := Config.ScanFolderSubFolders;
  PopulateListBox(lxTypes, Config.ScanFolderFileTypes);
  PopulateListBox(lxExclude, Config.ScanFolderExcludeNames);
end;

end.