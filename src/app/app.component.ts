import { Component, ViewContainerRef, ChangeDetectorRef, OnInit, ViewChild, ChangeDetectionStrategy } from '@angular/core';
import {WindowsManager, AboutWindow} from '@astonio/ui';
import {Backend, ListModel} from '@astonio/core';
import {ModelWindowsDispatcher} from '@astonio/model-ui';


@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AppComponent implements OnInit {
  @ViewChild('container', { read: ViewContainerRef }) containerVCR;
  tables:ListModel[] = [];
  views:ListModel[] = [];

  constructor(private wm:WindowsManager, private mwd:ModelWindowsDispatcher, private vcr:ViewContainerRef, private backend:Backend, private cdr:ChangeDetectorRef) {
    this.backend.bootstrapped.subscribe(() => {
      for (let list of this.backend.listModels.values()) {
        if (list.name == 'flow_product')
          continue;
          
        if (list.group == 'view') 
          this.views.push(list);
        else 
          this.tables.push(list);
      }
      this.cdr.markForCheck();

      this.openNewSale();
    });
  }
 
  openListWindow(listModel:ListModel) {
    var wnd = this.mwd.getListWindow(listModel, false, null, false).subscribe(wndInfo => {
      new wndInfo.window(this.wm, null, Object.assign({}, wndInfo.windowOptions, {list:listModel}));
    });
  }

  openNewSale() {
    var record = this.backend.getRecordModel('flow').constructRecord(true);
    this.mwd.getRecordWindow(record.__director__.model, null, false).subscribe(wndInfo => {
      var wnd = new wndInfo.window(this.wm, null, Object.assign({}, wndInfo.windowOptions, {record:record, edit:true}));
    });
  }

  ngOnInit() {
    this.wm.initVCR(this.containerVCR); // Так же это указывает, родительский элемент для создания окон.
  }

  openAbout() {
    var wnd = new AboutWindow(this.wm, null, 'Astonio Shop');
  }
}