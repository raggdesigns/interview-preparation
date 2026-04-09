# k6 basics

**Interview framing:**

"k6 is the load testing tool I reach for first. It's open source, runs from the CLI, uses JavaScript for test scripts, and is designed for developers rather than QA teams. The key differences from older tools like JMeter: scripts are code (not XML), it's command-line native (fits naturally into CI pipelines), and it thinks in terms of virtual users and scenarios rather than thread groups. The mental model is 'write a script that simulates what one user does, then tell k6 to run 200 of them at once'."

### The mental model

A k6 test script is a JavaScript module that exports a `default` function. That function is what one virtual user (VU) does in a loop. k6 runs many VUs in parallel, each executing the function repeatedly for the duration of the test.

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 50,
  duration: '5m',
};

export default function () {
  const res = http.get('https://api.example.com/products');

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });

  sleep(1); // Think time between requests
}
```

Run with: `k6 run script.js`

That's a complete load test: 50 virtual users, each hitting `/products` every ~1 second for 5 minutes, checking that responses are 200 and under 500ms.

### Stages — ramping load profiles

Instead of flat load, you can define stages that ramp VUs up and down:

```javascript
export const options = {
  stages: [
    { duration: '2m', target: 50 },   // ramp up to 50 VUs
    { duration: '5m', target: 50 },   // hold at 50
    { duration: '2m', target: 200 },  // ramp to 200 (stress)
    { duration: '5m', target: 200 },  // hold at 200
    { duration: '3m', target: 0 },    // ramp down
  ],
};
```

This profile starts with a load test, transitions to a stress test, and ramps down — all in one script. Each test type from [the types file](load_vs_stress_vs_soak_vs_spike_testing.md) maps to a specific stage profile.

### Scenarios — multiple workloads

Real systems have multiple types of users doing different things. Scenarios let you model this:

```javascript
export const options = {
  scenarios: {
    browse: {
      executor: 'constant-vus',
      vus: 100,
      duration: '10m',
      exec: 'browsing',
    },
    checkout: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '5m', target: 20 },
        { duration: '5m', target: 20 },
      ],
      exec: 'purchasing',
    },
  },
};

export function browsing() {
  http.get('https://api.example.com/products');
  sleep(2);
}

export function purchasing() {
  http.post('https://api.example.com/orders', JSON.stringify({
    product_id: 42,
    quantity: 1,
  }), { headers: { 'Content-Type': 'application/json' } });
  sleep(5);
}
```

Two scenarios run in parallel: 100 VUs browsing products and up to 20 VUs making purchases. This mirrors reality more closely than a single endpoint hammered uniformly.

### Executors — fine-grained control

Executors determine how k6 schedules virtual users. The most useful ones:

- **`constant-vus`** — fixed number of VUs for a duration. The simplest. Good for steady-state load tests.
- **`ramping-vus`** — VU count changes over stages. Good for stress tests and variable load profiles.
- **`constant-arrival-rate`** — maintain a fixed request rate regardless of response time. If the system slows down, k6 adds more VUs to keep the rate constant. **This is the executor for rate-based testing** (e.g., "test at exactly 500 RPS").
- **`ramping-arrival-rate`** — same but with stages for the arrival rate. Good for "ramp from 100 RPS to 1000 RPS".

The distinction between VU-based and rate-based is important:

- **VU-based:** "run 50 users, each doing one request per second" → actual rate depends on response time. Slow responses → fewer requests.
- **Rate-based:** "maintain 500 requests per second" → VU count adjusts automatically. Slow responses → more VUs spawned.

For most interview conversations, describe VU-based for user-simulation scenarios and rate-based for throughput testing.

### Checks and thresholds

**Checks** are assertions on individual responses. They don't stop the test; they report pass/fail rates.

```javascript
check(res, {
  'status is 200': (r) => r.status === 200,
  'body contains products': (r) => r.body.includes('products'),
  'response time < 300ms': (r) => r.timings.duration < 300,
});
```

**Thresholds** are pass/fail criteria for the whole test. If a threshold is violated, k6 exits with a non-zero code — which makes it a CI gate.

```javascript
export const options = {
  thresholds: {
    'http_req_duration': ['p(95)<500', 'p(99)<1000'],  // p95 < 500ms, p99 < 1s
    'http_req_failed': ['rate<0.01'],                   // error rate < 1%
    'checks': ['rate>0.95'],                            // 95%+ checks pass
  },
};
```

This is how k6 integrates into CI: if p95 latency exceeds 500ms, the pipeline fails. No manual review needed.

### Authentication and dynamic data

Real tests need to authenticate and use realistic data:

```javascript
import http from 'k6/http';
import { SharedArray } from 'k6/data';

// Load test data once, shared across VUs
const users = new SharedArray('users', function () {
  return JSON.parse(open('./test_users.json'));
});

export default function () {
  const user = users[__VU % users.length];

  // Login
  const loginRes = http.post('https://api.example.com/auth/login', JSON.stringify({
    email: user.email,
    password: user.password,
  }), { headers: { 'Content-Type': 'application/json' } });

  const token = loginRes.json('token');

  // Use the token for subsequent requests
  const headers = {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };

  const res = http.get('https://api.example.com/orders', { headers });
  check(res, { 'orders returned': (r) => r.status === 200 });

  sleep(1);
}
```

`SharedArray` loads data once and shares it across VUs efficiently. `__VU` is the virtual user number — using it as an index distributes users across VUs.

### k6 in CI

k6 runs from the command line and exits with a non-zero code on threshold violations. This makes CI integration trivial:

```yaml
# GitHub Actions
- name: Run load test
  uses: grafana/k6-action@v0.3.0
  with:
    filename: tests/load/checkout.js
    flags: --out json=results.json
```

Or just:
```yaml
- name: Install k6
  run: |
    curl -sL https://github.com/grafana/k6/releases/download/v0.49.0/k6-v0.49.0-linux-amd64.tar.gz | tar xz
    sudo mv k6-v0.49.0-linux-amd64/k6 /usr/local/bin/

- name: Run load test
  run: k6 run --out json=results.json tests/load/checkout.js
```

Thresholds fail the pipeline automatically. Results can be shipped to Grafana Cloud k6, InfluxDB + Grafana, or any time-series backend for historical comparison.

### Output and visualization

k6 can output results in several formats:

- **Console summary** — the default. Shows p50/p90/p95/p99 latency, RPS, error rate, check pass rates.
- **JSON** — `--out json=results.json`. Machine-readable.
- **InfluxDB** — `--out influxdb=http://localhost:8086/k6`. Feed into Grafana.
- **Prometheus Remote Write** — `--out experimental-prometheus-rw`. Direct to Prometheus.
- **Grafana Cloud k6** — managed, with built-in dashboards.
- **CSV** — `--out csv=results.csv`. For spreadsheet analysis.

For one-off tests, the console summary is fine. For historical tracking (regression detection across releases), push to InfluxDB or Prometheus and build Grafana dashboards.

### Writing realistic scenarios

The gap between a toy test and a useful test is realism. Principles:

- **Mix of operations.** Don't just hammer one endpoint. Model the actual traffic mix (80% reads, 15% searches, 5% writes, or whatever your analytics say).
- **Think time.** Real users pause between actions. `sleep(1)` to `sleep(5)` between requests simulates this. Without think time, you're testing a rate the system will never see from real users.
- **Realistic data.** Use parameterized data (user accounts, product IDs, search terms) that matches production distribution.
- **Session flow.** A checkout isn't one request — it's browse → add to cart → view cart → checkout → confirm. Model the flow, not isolated endpoints.
- **Ramp-up.** Don't start at full load. Ramp up gradually to simulate real traffic patterns and let caches warm.

### Environment variables for test configuration

```javascript
export const options = {
  vus: __ENV.VUS || 50,
  duration: __ENV.DURATION || '5m',
  thresholds: {
    'http_req_duration': [`p(95)<${__ENV.P95_THRESHOLD || 500}`],
  },
};

const BASE_URL = __ENV.BASE_URL || 'https://staging.example.com';
```

Run with: `k6 run -e BASE_URL=https://api.example.com -e VUS=200 script.js`

This makes the same script reusable across environments and load levels.

### Custom metrics

Beyond built-in metrics, k6 supports custom counters, gauges, rates, and trends:

```javascript
import { Trend, Counter } from 'k6/metrics';

const orderDuration = new Trend('order_creation_duration');
const ordersCreated = new Counter('orders_created');

export default function () {
  const start = new Date();
  const res = http.post(`${BASE_URL}/orders`, payload, { headers });
  orderDuration.add(new Date() - start);

  if (res.status === 201) {
    ordersCreated.add(1);
  }
}
```

Custom metrics appear in the output alongside built-ins and can have their own thresholds.

> **Mid-level answer stops here.** A mid-level dev can write a k6 script. To sound senior, speak to test realism, CI integration, and using k6 as part of a performance engineering practice ↓
>
> **Senior signal:** treating load test scripts as production code with version control, CI integration, realistic scenarios, and historical tracking.

### The test suite I maintain

For a typical service, I maintain three or four k6 scripts:

1. **`smoke.js`** — 5 VUs, 1 minute. Runs on every deploy to staging. Catches catastrophic regressions fast.
2. **`load.js`** — production-level VUs, 10 minutes. Runs weekly or before releases. Validates SLO compliance.
3. **`stress.js`** — ramp to 5x baseline. Runs monthly or before major launches. Finds the ceiling.
4. **`soak.js`** — baseline VUs, 4-8 hours. Runs quarterly. Finds leaks.

All scripts live in the repo under `tests/load/`, version-controlled and reviewed like any other code.

### Common mistakes

- **Testing one endpoint in isolation.** Real traffic is a mix; test the mix.
- **No think time.** Produces unrealistic request rates.
- **Flat load profile only.** Missing the ramp-up, stress, and spike patterns.
- **No thresholds.** Tests that always "pass" regardless of results teach nothing.
- **Testing staging with a tiny database.** Results don't reflect production.
- **Running from the same machine as the target.** Network and CPU contention corrupt results. Run k6 from a separate machine.
- **No historical comparison.** This week's results are only useful compared to last week's.
- **Scripts that aren't in version control.** They drift, break, and get lost.

### Closing

"So k6 is a developer-friendly, CLI-native load testing tool with JavaScript scripts, configurable scenarios and executors, CI-native thresholds, and output to any time-series backend. The scripts are code — versioned, reviewed, parameterized, and integrated into the deployment pipeline. The right practice is maintaining a small suite of scripts (smoke, load, stress, soak) that run at different cadences and compare against historical baselines. The scripts are easy to write; the discipline of running them consistently and acting on the results is the hard part."
