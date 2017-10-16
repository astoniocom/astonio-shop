import {Record, RecordDirector, ListModel, RecordModel, BaseField, RecordFieldValue, BaseBackend, 
  BaseDbFieldParams, BaseDbField, QuerySet, RowDoesNotExistError} from '@astonio/core';
import {SqlBackend} from '@astonio/mysql-backend';
import {Observable} from 'rxjs';
import {round} from './utils';


export class FlowProductRecordDirector extends RecordDirector {
  

  getDate(flow:Record):Observable<Date> {
    if (flow) {
      return flow.__director__.getData().map(flowRecord => {
        return flowRecord['date'] ? flowRecord['date'] : new Date();
      });
    }
    else {
      return Observable.of(new Date());
    }
  }

  getRate(flow:Record):Observable<number> {
    return this.getDate(flow).flatMap(date => {
      return this.backend.getListModel('rates').getQueryset().orderBy('-date').filter({date__lte: date}).limit(0,1).getRow();
    }).map(rateRecord => {
      return rateRecord['rate'];
    });
  }

  onValueChanged(field:BaseField, newValue: RecordFieldValue, oldValue:RecordFieldValue) {
    if (field.name == 'flow_product__product' && this.host['flow_product__flow'] && this.host['flow_product__flow']['type'] == 'Реализация') {
      var product:Record = this.host[field.name];
      if (!product)
        return;

      product.__director__.getData().subscribe(record => {
        if (record['price']) {
          this.host['price_out_usd'] = record['price'];
          this.getRate(this.host['flow_product__flow']).subscribe(rate => {
            this.host['price_out_r_auto'] = true;
            this.host['price_out_r'] = round(this.host['price_out_usd'] * rate);
          });
        }

        this.getDate(this.host['flow_product__flow']).subscribe(date => {
          this.backend.getListModel('remains').getQueryset().filter({balance__gt: 0, product_name:product['name'], storage: this.host['flow_product__flow']['storage']}).limit(0,1).getRow().catch(err => {
            if (err instanceof RowDoesNotExistError) {
              return this.backend.getListModel('remains_common').getQueryset().filter({balance__gt: 0, product_name:product['name']}).limit(0,1).getRow()
            }
            throw err;
          }).subscribe(remainsRecord => {//, date__lt: date orderBy('date').
            this.host['price_in_usd'] = remainsRecord['price_in_usd'];
          });
        });
      });
    }

    if (field.name == 'price_out_r' && this.host['price_out_r']!==null) {
      if (!this.host['price_out_r_auto'])
        this.host['manualPrice'] = true;
      else 
        this.host['price_out_r_auto'] = false;
      this.getRate(this.host['flow_product__flow']).subscribe(rate => {
        this.host['price_out_usd'] = round(this.host['price_out_r'] / rate);
      });
    }


    if (field.name == 'price_out_r' || field.name == 'qty' && (this.host['price_out_r'] && this.host['qty'])) {
      this.host['total_rub'] = round(this.host['price_out_r'] * this.host['qty']);
    }
    if (field.name == 'price_out_usd' || field.name == 'qty' && (this.host['price_out_usd'] && this.host['qty'])) {
      this.host['total_usd'] = round(this.host['price_out_usd'] * this.host['qty']);
    }
  }
}

export class AstonioShopBackend extends SqlBackend {
  getRecordDirector(model:RecordModel):typeof RecordDirector {
    if (model.name == 'flow_product')
      return FlowProductRecordDirector;
    return super.getRecordDirector(model);
  }

  getModelField(tableName:string, fieldName:string, fieldClass:{new(backend:BaseBackend, fieldParams:BaseDbFieldParams): BaseDbField}, fieldParams:BaseDbFieldParams):BaseDbField {
    if (tableName == 'flow' && fieldName == 'date') {
      fieldParams.default = () => new Date();
    }
    return super.getModelField(tableName, fieldName, fieldClass, fieldParams);
  }

  getQueryset(table:ListModel):QuerySet {
    var qs = super.getQueryset(table);
    if (table.name == 'flow' || table.name == 'rates')
      qs = qs.orderBy('-date');
    return qs;
  }

  representRecord(record:Record) {
    if (record.__director__.model.name == 'product' && !record.__director__.isNew) {
      return record['name'];
    }
    return undefined;
  }
}