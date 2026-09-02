/*
 * Robot Window for the SJSU software testing lab.
 *
 * The window is deliberately dumb: it renders whatever specification the
 * Supervisor sends it and posts parameter values back.  Ranges, scenarios and
 * requirements all live in controllers/test_supervisor/lab_spec.py, so the form
 * the student sees can never disagree with the validation the Supervisor
 * actually performs.
 *
 * Messages received from the Supervisor:
 *   {type:"spec", parameters, scenarios, requirements, constants}
 *   {type:"status", state, message}
 *   {type:"sample", sample:{t,x,y,clearance,distance_to_goal}}
 *   {type:"result", ...measurements, checks, verdict, reason}
 *   {type:"rejected", errors, message}
 *
 * Messages sent to the Supervisor:
 *   {cmd:"hello"} {cmd:"run", params:{...}} {cmd:"reset"}
 */

(function () {
  'use strict';

  var spec = null;
  var log = [];
  var runCounter = 0;

  function $(id) { return document.getElementById(id); }

  function setStatus(state, message) {
    var el = $('status');
    el.className = 'status ' + state;
    el.textContent = message;
    $('run').disabled = (state === 'running');
  }

  // -- form -------------------------------------------------------------

  function buildForm() {
    var form = $('params');
    form.innerHTML = '';

    spec.parameters.forEach(function (p) {
      var wrap = document.createElement('div');
      wrap.className = 'field';
      wrap.id = 'field-' + p.key;

      var label = document.createElement('label');
      label.setAttribute('for', 'in-' + p.key);
      label.textContent = p.label + (p.unit ? ' (' + p.unit + ')' : '');
      wrap.appendChild(label);

      var input;
      if (p.kind === 'enum') {
        input = document.createElement('select');
        p.choices.forEach(function (choice) {
          var option = document.createElement('option');
          option.value = choice;
          option.textContent = (spec.scenarios[choice] &&
                                spec.scenarios[choice].label) || choice;
          input.appendChild(option);
        });
      } else {
        input = document.createElement('input');
        // Deliberately a text box, not a spinner clamped to the legal range:
        // students must be able to type an out-of-range value and watch the
        // system reject it.  That is REQ-5.
        input.type = 'text';
        input.inputMode = 'decimal';
      }
      input.id = 'in-' + p.key;
      input.name = p.key;
      input.value = p.default;
      input.addEventListener('input', function () {
        wrap.classList.remove('invalid');
        if (p.key === 'scenario') { applyScenarioVisibility(); }
      });
      input.addEventListener('change', function () {
        if (p.key === 'scenario') { applyScenarioVisibility(); }
      });
      wrap.appendChild(input);

      if (p.kind !== 'enum') {
        var range = document.createElement('p');
        range.className = 'range';
        range.textContent = 'Allowed: ' + p.min + ' … ' + p.max
          + (p.unit ? ' ' + p.unit : '');
        wrap.appendChild(range);
      }
      if (p.help) {
        var help = document.createElement('p');
        help.className = 'help';
        help.textContent = p.help;
        wrap.appendChild(help);
      }
      var err = document.createElement('p');
      err.className = 'err';
      wrap.appendChild(err);

      form.appendChild(wrap);
    });

    applyScenarioVisibility();
  }

  // Parameters that only matter for one scenario are hidden elsewhere; they are
  // still sent, and still validated, so a hidden field can never smuggle an
  // illegal value past the Supervisor.
  var SCENARIO_ONLY = ['obstacle_x', 'obstacle_y', 'corridor_width'];

  function applyScenarioVisibility() {
    var scenario = $('in-scenario').value;
    var extras = (spec.scenarios[scenario] &&
                  spec.scenarios[scenario].extra_params) || [];
    SCENARIO_ONLY.forEach(function (key) {
      var field = $('field-' + key);
      if (!field) { return; }
      field.classList.toggle('hidden', extras.indexOf(key) === -1);
    });
    var note = $('scenario-note');
    if (!note) {
      note = document.createElement('p');
      note.id = 'scenario-note';
      note.className = 'help';
      $('field-scenario').appendChild(note);
    }
    note.textContent = (spec.scenarios[scenario] &&
                        spec.scenarios[scenario].description) || '';
  }

  function collectParams() {
    var params = {};
    spec.parameters.forEach(function (p) {
      params[p.key] = $('in-' + p.key).value;
    });
    return params;
  }

  function markErrors(errors) {
    document.querySelectorAll('.field').forEach(function (f) {
      f.classList.remove('invalid');
    });
    errors.forEach(function (message) {
      var match = /\('([a-z_]+)'\)/.exec(message);
      if (!match) { return; }
      var field = $('field-' + match[1]);
      if (!field) { return; }
      field.classList.add('invalid');
      field.querySelector('.err').textContent = message;
    });
  }

  // -- requirements ------------------------------------------------------

  function renderRequirements() {
    var list = $('requirements');
    list.innerHTML = '';
    spec.requirements.forEach(function (r) {
      var li = document.createElement('li');
      var id = document.createElement('span');
      id.className = 'id';
      id.textContent = r.id;
      var text = document.createElement('span');
      text.textContent = r.text;
      li.appendChild(id);
      li.appendChild(text);
      list.appendChild(li);
    });
  }

  // -- results -----------------------------------------------------------

  function yesNo(value) { return value ? 'Yes' : 'No'; }

  function showResult(r) {
    $('verdict').className = 'verdict ' + r.verdict.toLowerCase();
    $('verdict').textContent = r.verdict === 'PASS' ? 'PASS' : 'FAIL';
    $('reason').textContent = r.reason;

    $('m-goal').textContent = yesNo(r.goal_reached);
    $('m-collision').textContent = r.collision
      ? 'Yes (' + r.collision_object + ')' : 'No';
    $('m-time').textContent = r.completion_time.toFixed(2) + ' s'
      + (r.timed_out ? ' (timed out)' : '');
    $('m-clearance').textContent = r.min_clearance.toFixed(3) + ' m';
    $('m-arena').textContent = yesNo(!r.left_arena);
    $('m-path').textContent = r.path_length.toFixed(3) + ' m';
    $('m-final').textContent = r.final_distance_to_goal.toFixed(3) + ' m';

    renderChecks(r.checks);
    addLogRow(r);
  }

  function showRejection(payload) {
    $('verdict').className = 'verdict rejected';
    $('verdict').textContent = 'INPUT REJECTED — no test executed';
    $('reason').textContent = payload.errors.join('  ');
    ['m-goal', 'm-collision', 'm-time', 'm-clearance', 'm-arena', 'm-path',
     'm-final'].forEach(function (id) { $(id).textContent = '–'; });
    renderChecks(payload.checks || []);
    markErrors(payload.errors);
    addLogRow({
      verdict: 'REJECTED',
      params: collectParams(),
      reason: payload.errors.join('  '),
    });
  }

  function renderChecks(checks) {
    var list = $('checks');
    list.innerHTML = '';
    if (!checks.length) {
      list.innerHTML = '<li class="muted">No checks reported.</li>';
      return;
    }
    checks.forEach(function (c) {
      var li = document.createElement('li');
      var tag = document.createElement('span');
      tag.className = 'tag ' + c.status.toLowerCase();
      tag.textContent = c.status;
      var id = document.createElement('span');
      id.className = 'id';
      id.textContent = c.id;
      var detail = document.createElement('span');
      detail.textContent = c.detail;
      li.appendChild(tag);
      li.appendChild(id);
      li.appendChild(detail);
      list.appendChild(li);
    });
  }

  // -- test log ----------------------------------------------------------

  function addLogRow(r) {
    runCounter += 1;
    var p = r.params || {};
    var row = {
      n: runCounter,
      scenario: p.scenario,
      speed: p.speed,
      corridor: p.corridor_width,
      noise: p.sensor_noise,
      limit: p.max_time,
      time: r.completion_time,
      clearance: r.min_clearance,
      goal: r.goal_reached,
      collision: r.collision,
      verdict: r.verdict,
      reason: r.reason,
    };
    log.push(row);

    var body = $('log-body');
    if (log.length === 1) { body.innerHTML = ''; }
    var tr = document.createElement('tr');
    tr.className = row.verdict.toLowerCase();
    function cell(text, cls) {
      var td = document.createElement('td');
      if (cls) { td.className = cls; }
      td.textContent = text;
      tr.appendChild(td);
    }
    function num(v, digits) {
      return (v === undefined || v === null || v === '') ? '–'
        : Number(v).toFixed(digits);
    }
    cell(row.n, 'num');
    cell(row.scenario || '–');
    cell(num(row.speed, 2), 'num');
    cell(row.scenario === 'CORRIDOR' ? num(row.corridor, 2) : '–', 'num');
    cell(num(row.noise, 2), 'num');
    cell(num(row.limit, 0), 'num');
    cell(row.time === undefined ? '–' : num(row.time, 2), 'num');
    cell(row.clearance === undefined ? '–' : num(row.clearance, 3), 'num');
    cell(row.goal === undefined ? '–' : yesNo(row.goal));
    cell(row.collision === undefined ? '–' : yesNo(row.collision));
    cell(row.verdict, 'v');
    cell(row.reason || '', 'reason');
    body.insertBefore(tr, body.firstChild);
  }

  function exportCsv() {
    if (!log.length) { return; }
    var header = ['run', 'scenario', 'speed_rad_s', 'corridor_width_m',
                  'sensor_noise', 'time_limit_s', 'completion_time_s',
                  'min_clearance_m', 'goal_reached', 'collision', 'verdict',
                  'reason'];
    var lines = [header.join(',')];
    log.forEach(function (r) {
      lines.push([
        r.n, r.scenario, r.speed, r.corridor, r.noise, r.limit,
        r.time, r.clearance, r.goal, r.collision, r.verdict,
        '"' + String(r.reason || '').replace(/"/g, '""') + '"',
      ].join(','));
    });
    var blob = new Blob([lines.join('\n')], { type: 'text/csv' });
    var a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'test_log.csv';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(a.href);
  }

  // -- wiring ------------------------------------------------------------

  function handle(message) {
    var payload;
    try {
      payload = JSON.parse(message);
    } catch (e) {
      return;
    }

    switch (payload.type) {
      case 'spec':
        spec = payload;
        buildForm();
        renderRequirements();
        break;
      case 'status':
        setStatus(payload.state, payload.message);
        break;
      case 'sample':
        $('t-time').textContent = payload.sample.t.toFixed(2);
        $('t-pos').textContent = '(' + payload.sample.x.toFixed(3) + ', '
          + payload.sample.y.toFixed(3) + ')';
        $('t-clear').textContent = payload.sample.clearance.toFixed(3);
        $('t-goal').textContent = payload.sample.distance_to_goal.toFixed(3);
        break;
      case 'result':
        showResult(payload);
        break;
      case 'rejected':
        showRejection(payload);
        break;
      default:
        break;
    }
  }

  function send(payload) {
    if (window.robotWindow) {
      window.robotWindow.send(JSON.stringify(payload));
    }
  }

  window.addEventListener('load', function () {
    if (window.robotWindow) {
      window.robotWindow.receive = handle;
    }

    $('run').addEventListener('click', function () {
      document.querySelectorAll('.field').forEach(function (f) {
        f.classList.remove('invalid');
      });
      send({ cmd: 'run', params: collectParams() });
    });
    $('reset').addEventListener('click', function () {
      send({ cmd: 'reset' });
    });
    $('defaults').addEventListener('click', function () {
      if (!spec) { return; }
      spec.parameters.forEach(function (p) {
        $('in-' + p.key).value = p.default;
      });
      document.querySelectorAll('.field').forEach(function (f) {
        f.classList.remove('invalid');
      });
      applyScenarioVisibility();
    });
    $('export').addEventListener('click', exportCsv);
    $('clear-log').addEventListener('click', function () {
      log = [];
      runCounter = 0;
      $('log-body').innerHTML = '<tr><td colspan="12" class="muted">'
        + 'Runs you execute will be listed here.</td></tr>';
    });

    // The Supervisor sends the specification unprompted at start-up, but the
    // window can be opened later, so ask for it as well.
    send({ cmd: 'hello' });
    setStatus('idle', 'Waiting for the Supervisor…');
  });
}());
