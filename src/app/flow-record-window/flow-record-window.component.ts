import {Component, Injector, ViewChild, AfterViewInit, ChangeDetectorRef, NgZone} from '@angular/core';
import {Backend, Record, RelatedRecords} from '@astonio/core';
import {RecordWindowComponent, RelatedRecordsGridComponent} from '@astonio/model-ui'
import {TextInputWidgetComponent} from '@astonio/ui'
import {round} from '../utils';

@Component({
  templateUrl: "./flow-record-window.html"
})
export class FlowRecordWindowComponent extends RecordWindowComponent implements AfterViewInit {
  @ViewChild('grid') grid:RelatedRecordsGridComponent;
  @ViewChild('barcodeInput') barcodeInput:TextInputWidgetComponent;
  
  barcode:string;
  backend:Backend;
  cdr:ChangeDetectorRef;
  zone:NgZone;

  constructor(protected injector:Injector) {
    super(injector);
    this.backend = injector.get(Backend);
    this.cdr = injector.get(ChangeDetectorRef);
    this.zone = injector.get(NgZone);
  }

  ngAfterViewInit() {
    if (this.barcodeInput) // В режиме просмотре фокус не устанавливаем
      this.barcodeInput.setFocus();
  }

  onRenderCell(ev) {
    if (ev.col.field == 'flow_product__product' && ev.rowData.product_name) {
      ev.componentRef.instance.repr = ev.rowData.product_name;
    }
  }
  onInputKeyDown(ev) {
    if (ev.key != "Enter" || this.barcode == "")
      return;
    this.backend.getListModel('product').getQueryset().filter({barcode: this.barcode}).getRow().subscribe(product => {
      var newRow:Record = this.backend.getRecordModel('flow_product').constructRecord(true);//{flow_product__flow: this.record, flow_product__product:product, qty:1}
      (this.record['flow_product__flow_set'] as RelatedRecords).add(newRow);
      newRow['flow_product__product'] = product;
      newRow['qty'] = 1;
      this.barcode = "";
    });
  }

  onRecordChanged(ev) {
    this.zone.run(() => {
      (this.record['flow_product__flow_set'] as RelatedRecords).getRecords().subscribe(records => {
        let total = 0;
        for (let record of records) {
          total += record['total_rub'];
        }
        this.record['total'] = round(total);
      });
    });
  }

  getChangeValue() {
    return round(this.record['cash'] - this.record['total']);
  }
 

  //{rowData:any, col:GridColumn, oldValue:any, newValue:any}
  onCellValueChanged($event) {
    if ($event.col.field == 'qty' || $event.col.field == 'price_out_r') {
      var pos = (this.record['flow_product__flow_set'] as RelatedRecords).items.indexOf($event.rowData);
      if (pos !== -1 && pos < (this.record['flow_product__flow_set'] as RelatedRecords).items.length-1)   {
        setTimeout(() => {
          this.grid.focusCell((this.record['flow_product__flow_set'] as RelatedRecords).items[pos+1], $event.col.field);
        });
      }
    }
  }
}

