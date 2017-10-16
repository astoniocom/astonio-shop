import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';
import {FlexLayoutModule} from '@angular/flex-layout';
import {SqlBackend} from '@astonio/mysql-backend';
import {Backend} from '@astonio/core';
import {AstonioUIModule, WindowsManager, BaseDataStorageService, LocalDataStorageService} from '@astonio/ui';
import {VentusWindowsManager} from '@astonio/ventus-wm';
import {AstonioModelUIModule} from '@astonio/model-ui'
import {FormsModule} from '@angular/forms';

import {ModelWindowsDispatcher} from '@astonio/model-ui';
import {FlowRecordWindowComponent} from './flow-record-window/flow-record-window.component';
import {RecordWindow} from '@astonio/model-ui';
import {AstonioShopBackend} from './backend';
import {ReplaySubject} from 'rxjs';
import { AppComponent } from './app.component';
import ssh2 from 'ssh2';

var config = {
  ssh: {
    host: '',
    username: '',
    password: '',
    port:undefined,
    keepaliveInterval: 4000,
    readyTimeout: 5000,
  },
  mysql: {
    host: 'localhost',
    user: '',
    password: '',
    database: '',
  }
};

if (config.ssh) {
  var sshReady = new ReplaySubject<any>();
  var Client = ssh2.Client;
  var ssh = new Client();
  ssh.on('ready', function() {
    sshReady.next(ssh);
    //config['mysql']['sshClient'].complete();
  })
  .on('error', function(error) {
    console.log(error);
    console.log('Connection error. New attempt.');
    setTimeout(() => {
      ssh.connect(config.ssh);
    }, 4000);
  }).connect(config.ssh);

  config['mysql']['stream'] = function (cb) {
    sshReady.subscribe(function (_ssh) {
      if (!_ssh)
        return;
      this.unsubscribe();
      _ssh.forwardOut('127.0.0.1', 0, 'localhost', config.ssh.port || 3306, (err, stream) => {
        if (err) { 
          alert("Connection error. Repeat query.")
          throw err;
        }
        cb(stream);
      });
    });
  }
};

export var backend = new AstonioShopBackend(config.mysql);
backend.bootstrap().subscribe(() => {

});

var modelUiConfig = {
  listWindow: {
    flow: {
      readonly: ['*'],
      fields: ['__repr__',{exclude:['flow_product__flow_set']}]
    },
    product: {
      fields: ['__repr__',{exclude:['flow_product__product_set']}]
    }
  },
  recordWindow: {
    product: {
      fields: [{exclude:['flow_product__product_set', 'id']}]
    }
  }

}

@NgModule({
  declarations: [
    AppComponent,
    FlowRecordWindowComponent
  ],
  imports: [
    BrowserModule,
    FlexLayoutModule,
    FormsModule,
    AstonioUIModule.forRoot(),
    AstonioModelUIModule.forRoot(modelUiConfig)
  ],
  providers: [
    {provide: Backend, useValue: backend},
    LocalDataStorageService,
    VentusWindowsManager,
    {provide: WindowsManager, useExisting: VentusWindowsManager},
    {provide: BaseDataStorageService, useExisting: LocalDataStorageService},
  ],
  entryComponents: [
    FlowRecordWindowComponent
  ],
  bootstrap: [AppComponent]
})
export class AppModule {
  constructor(protected mwd:ModelWindowsDispatcher, protected wm:WindowsManager) {
    mwd.registerRecordWindow({window: RecordWindow, recordModel:'flow', windowOptions: {component: FlowRecordWindowComponent}});
  }
}

