/*
 * decaffeinate suggestions:
 * DS001: Remove Babel/TypeScript constructor workaround
 * DS102: Remove unnecessary code created because of implicit returns
 * DS206: Consider reworking classes to avoid initClass
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const app = angular.module("app");

app.factory("Timeframe", ["RailsResource", "railsSerializer", function(RailsResource, railsSerializer){
  class Timeframe extends RailsResource {
    static initClass() {
      this.configure({url: '/timeframes', name: 'timeframe', serializer: railsSerializer(function() {
        this.exclude("client");
        return this.resource("worklog", "Worklog");
      })
      });
    }
    constructor(opts){
      {
        // Hack: trick Babel/TypeScript into allowing this before super.
        if (false) { super(); }
        let thisFn = (() => { return this; }).toString();
        let thisName = thisFn.slice(thisFn.indexOf('return') + 6 + 1, thisFn.indexOf(';')).trim();
        eval(`${thisName} = this;`);
      }
      const defaultOpts = {
        started: null,
        ended: null,
        client: null
      };
      const _this = this;
      const useOpts = _.extend(defaultOpts, opts);
      _.each(useOpts, (val, key) => _this[key] = val);
    }

    calcTotal(ratePerSecond){
      if (ratePerSecond && this.started && this.ended) {
        return this.durationSeconds() * ratePerSecond;
      } else {
        return 0;
      }
    }
    durationSeconds() {
      // For some reason the provided @ended and @started formats aren't working.
      // It's necessary to recreate a new Date, based on the dates provided.
      // Else the calculation causes a NaN
      return (((new Date(this.ended)) - (new Date(this.started))) / 1000);
    }

    setEndedNow() {
      return this.ended = new Date();
    }

    setStartedNow() {
      return this.started = new Date();
    }

    checkForIssues() {
      const issues = [];
      // TimeFrame more than 10 hours.
      const tenHours = 3600 * 10;
      if (this.started && this.ended && (this.durationSeconds() >= tenHours)) {
        issues.push("Duration is longer than 10 hours. Please double-check.");
      }
      if (this.started && this.ended && (this.durationSeconds() < 0)) {
        issues.push("Duration is smaller 0. Please check.");
      }
      return issues;
    }

    issueDetected() {
      return this.checkForIssues().length > 0;
    }
  }
  Timeframe.initClass();

  return Timeframe;
}
]);