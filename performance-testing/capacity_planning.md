# Capacity planning

**Interview framing:**

"Capacity planning is the practice of predicting how much infrastructure you'll need to handle future traffic — and being right enough to avoid both over-provisioning (wasting money) and under-provisioning (degrading under load). The core skill is connecting business growth projections to infrastructure requirements through a chain of measured relationships: traffic growth → request rate → resource consumption → infrastructure needed. It's not precise science — it's informed estimation, and the goal is to be roughly right, not exactly wrong."

### The capacity planning process

1. **Measure current state.** What's your traffic now? What resources does it consume?
2. **Forecast future demand.** What will traffic look like in 3/6/12 months?
3. **Model the relationship.** How does traffic translate to resource consumption?
4. **Compute future resource needs.** Apply the model to the forecast.
5. **Add headroom.** Buffer for spikes, errors in the model, and planned growth.
6. **Plan the infrastructure changes.** Provision, schedule, budget.
7. **Validate.** Revisit predictions against actual outcomes. Calibrate the model.

### Step 1: Measure current state

You need numbers, not vibes. Baseline metrics:

- **Traffic:** requests per second (RPS), peak vs average, by endpoint or service.
- **Resource usage at current traffic:**
  - CPU utilization at peak (per pod, per node).
  - Memory usage at peak.
  - Database connections (active, idle, max).
  - Database query volume and latency (from `pg_stat_statements` or equivalent).
  - Cache hit rate and eviction rate.
  - Queue depth and consumer throughput.
  - Disk I/O and storage growth rate.
- **Headroom:** how much capacity is unused at peak? This is your current safety margin.

Express these as ratios: "at 500 RPS, we use 4 CPU cores (200m per pod × 20 pods), 8 GB of memory, 50 DB connections, and p95 latency is 120ms."

### Step 2: Forecast future demand

Traffic forecasting is part data, part business context:

- **Historical growth.** What's the month-over-month or year-over-year growth in traffic? Plot it.
- **Business plans.** Is a marketing campaign launching? A new market? A product launch?
- **Seasonality.** E-commerce has Black Friday; SaaS has end-of-quarter; media has breaking news.
- **Organic vs event-driven.** Organic growth is gradual; events are spikes. Plan for both.

The simplest useful model: **linear extrapolation with a multiplier for events.**

"Traffic has grown 5% month-over-month for the last 6 months. In 6 months, traffic will be ~1.34x current. Black Friday will be ~3x current for 72 hours."

More sophisticated models use exponential growth, user acquisition funnels, conversion rates, etc. — but for most teams, linear extrapolation with event multipliers is sufficient.

### Step 3: Model the relationship

The key question: **how does traffic translate to resources?**

The simplest approach: **measure the ratio under load testing.**

Run your load test suite at 1x, 2x, and 3x current traffic. Record resource usage at each level. Plot traffic vs resource consumption. For most web services, the relationship is roughly linear up to a saturation point, then degrades.

```
RPS:  500   1000   1500   2000   2500
CPU:  20%    40%    60%    80%    95% ← saturation
Mem:  4GB    4GB    4GB    5GB    8GB ← memory pressure starts here
DB:   50     100    150    195    200 ← pool max hit
p95:  120ms  130ms  200ms  500ms  2s  ← latency degradation
```

From this table: the system is linear up to ~2000 RPS, then CPU saturates and latency degrades. The database connection pool is a hard limit at 200. Memory is stable until pressure drives GC and swap.

### Step 4: Compute future resource needs

Apply the forecast to the model:

"In 6 months, organic traffic will be 1.34x = 670 RPS. Black Friday will be 3x = 1500 RPS."

From the model:
- At 670 RPS: 27% CPU, comfortable. No changes needed for organic growth.
- At 1500 RPS: 60% CPU, 150 DB connections, p95 ~200ms. Manageable but approaching the discomfort zone.
- At 2000 RPS (if the event is bigger than expected): saturation. Need to pre-scale.

Planning: for organic growth, no action needed for 6 months. For Black Friday, either pre-scale or ensure HPA can handle the spike.

### Step 5: Add headroom

Raw projections should not be your provisioning target. Add headroom for:

- **Forecast error.** Traffic projections are always wrong. 20-50% buffer is reasonable.
- **Operational overhead.** Deploys, rolling restarts, node failures — you need spare capacity to handle these without impacting users.
- **Efficiency loss under load.** Real systems are less efficient at high utilization than at moderate utilization. Plan for 60-70% peak utilization, not 90%.
- **Unexpected events.** Viral posts, bot attacks, retry storms. 2-3x headroom for short-duration spikes.

The rule of thumb: **plan for 70% utilization at predicted peak.** This gives you 30% buffer for errors, spikes, and operational events.

### Step 6: Plan infrastructure changes

Convert resource needs into infrastructure decisions:

- **Horizontal scaling.** More pods/instances. The simplest lever for stateless services.
- **Vertical scaling.** Larger instances. Simpler but has a ceiling.
- **Database scaling.** Read replicas for read-heavy workloads. Connection pooling (PgBouncer) for connection-heavy workloads. Sharding for write-heavy workloads (complex, last resort).
- **Cache scaling.** Larger Redis instances, more cache nodes, or a dedicated caching layer.
- **CDN and edge caching.** Offload static and semi-static content.
- **Auto-scaling.** HPA for Kubernetes, auto-scaling groups for cloud VMs. Handles organic variation automatically; may not be fast enough for sudden spikes.

Plan changes with lead time. Provisioning a new database replica takes days, not minutes. Pre-scaling for a known event should start a week before, not the night before.

### Step 7: Validate

After the event (or after 3 months of organic growth), compare predictions to reality:

- Was the traffic forecast accurate? If not, why?
- Was the resource model accurate? Did the system behave as predicted under load?
- Were there surprises? (A new bottleneck that didn't appear in testing, a traffic pattern that didn't match the model.)
- Calibrate for the next cycle.

Capacity planning is iterative. Each cycle improves the model.

### Back-of-envelope estimation — the interview skill

Interviewers often ask "how would you design a system to handle X million requests per day?" This is a capacity planning exercise, done quickly.

**The basic conversions:**

- 1 million requests/day ≈ 12 RPS (1,000,000 / 86,400)
- Peak is usually 2-3x average, so 12 RPS average → 24-36 RPS peak.
- 1 web server handling 100 RPS → need 1 server for this load (with headroom).
- 100 million requests/day ≈ 1200 RPS average → ~3000 RPS peak → 30 servers at 100 RPS each.

**Storage:**
- 1 KB per row × 1 million rows/day = 1 GB/day = ~365 GB/year.
- With indexes and overhead: ~2-3x raw data = ~1 TB/year.

**Memory:**
- A typical PHP worker uses 50-100 MB.
- 20 workers × 100 MB = 2 GB for PHP alone.
- Add database buffer pool, cache, OS overhead → 8-16 GB per server is typical.

**Database:**
- PostgreSQL on SSD handles 5,000-50,000 simple queries/second depending on complexity.
- A connection pool of 100-200 handles most workloads.
- Read replicas for read-heavy workloads at 70%+ read ratio.

These are rough numbers. The point is to produce a plausible estimate quickly, identify the biggest unknowns, and know what to measure more carefully.

### The "how much does this cost" question

Capacity planning connects directly to cost. The capacity plan produces a bill of materials; the cost is the cloud provider's pricing for that infrastructure.

Interviewers sometimes ask "what would this cost?" A rough answer:

- A standard web application at 1000 RPS with PostgreSQL, Redis, and a message broker runs on ~$2,000-$5,000/month in cloud infrastructure (depending on provider, region, instance choices, and managed vs self-hosted services).
- Scale linearly for higher traffic (roughly, until you hit non-linear scaling challenges).
- Managed services (RDS, ElastiCache, managed Kubernetes) add 30-100% premium over self-hosted.

> **Mid-level answer stops here.** A mid-level dev can describe the process. To sound senior, speak to the iterative nature, the common failure modes, and the organizational discipline required ↓
>
> **Senior signal:** treating capacity planning as a continuous practice rather than a one-time exercise, connected to business planning and engineering budgets.

### The organizational dimension

Capacity planning isn't just an engineering exercise — it's a business exercise:

- **Engineering provides the model.** "At current growth, we'll need 2x infrastructure in 12 months."
- **Product provides the forecast.** "We're launching in a new market in Q3; expect 50% traffic growth."
- **Finance provides the budget.** "We can spend $X on infrastructure next quarter."
- **Together they produce the plan.** "We'll pre-provision for Q3, evaluate auto-scaling vs fixed capacity, and review in September."

The failure mode is engineering planning in isolation — accurate technically but disconnected from business reality.

### Common mistakes

- **Not planning at all.** "We'll scale when we need to." By the time you know you need to, it's too late.
- **Planning based on theory, not measurement.** "Each request takes 100ms" is a guess. Profile and load test to get real numbers.
- **Planning for average, not peak.** Average traffic is never the problem. Peak traffic is.
- **No headroom.** Planning for exactly the predicted load with zero buffer. One surprise and you're down.
- **Over-provisioning permanently for temporary spikes.** Pre-scale for Black Friday; scale back after. Don't run 3x capacity year-round for a 3-day event.
- **Ignoring the database.** The application tier is easy to scale horizontally. The database isn't. Plan database capacity first.
- **Not validating predictions.** The model drifts from reality if you never check.
- **Planning once and never again.** Traffic patterns change, code changes, data grows. Quarterly review is minimum.

### The capacity planning checklist

- [ ] Current baseline measured: RPS, resource usage at peak, headroom.
- [ ] Growth forecast obtained from business/product.
- [ ] Load testing validates the resource-to-traffic model.
- [ ] Future resource needs computed with headroom (target 70% peak utilization).
- [ ] Database capacity planned separately (it's the hardest to scale).
- [ ] Auto-scaling configured for organic variation.
- [ ] Pre-scaling planned for known events (launches, campaigns, holidays).
- [ ] Budget approved.
- [ ] Post-event validation scheduled.

### Closing

"So capacity planning is: measure current state, forecast future demand, model the relationship between traffic and resources, compute future needs with headroom, plan the infrastructure changes, and validate after the fact. The skill is connecting business growth to infrastructure requirements through measured ratios, and the discipline is doing it continuously — quarterly reviews, pre-event planning, post-event validation. Back-of-envelope estimation for interview questions uses simple RPS-to-server ratios; real planning uses load test data. Either way, plan for peak, not average, and always add headroom."
