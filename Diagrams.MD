# 보고서용 다이어그램 모음 (mermaid)

각 코드를 mermaid.live 또는 VS Code mermaid 미리보기에서 렌더링한 뒤 캡처하여,
보고서의 `[다이어그램 N]` 자리에 이미지로 삽입하세요.

---

## 다이어그램 1: 전체 아키텍처 개요

```mermaid
flowchart LR
    subgraph APP["애플리케이션 클러스터 (dev / stg / prod)"]
        OTEL["OpenTelemetry<br/>로그·트레이스·메트릭 수집"]
    end
    subgraph MGMT["mgmt 클러스터 (중앙)"]
        direction TB
        VL["VictoriaLogs<br/>로그"]
        VT["VictoriaTraces<br/>트레이스"]
        VM["VictoriaMetrics<br/>메트릭"]
        GF["Grafana<br/>통합 조회 + 알림"]
        VL --> GF
        VT --> GF
        VM --> GF
    end
    OTEL -->|"OTLP"| VL
    OTEL -->|"OTLP"| VT
    OTEL -->|"OTLP"| VM
```

---

## 다이어그램 2: 3대 신호의 수집 경로 차이

```mermaid
flowchart LR
    APP["애플리케이션"]
    APP -->|"표준출력"| F["노드 파일<br/>/var/log/pods"]
    F -->|"Agent가 읽음"| OT["OTel Collector"]
    APP -->|"트레이스: OTLP 직접 전송<br/>(앱 계측 필요)"| OT
    APP -->|"메트릭: scrape 또는 OTLP"| OT
    OT --> BE["저장 백엔드로"]
```

---

## 다이어그램 3: Agent/Gateway 2단 수집 구조

```mermaid
flowchart LR
    subgraph CL["클러스터"]
        direction TB
        N1["노드1: OTel Agent"]
        N2["노드2: OTel Agent"]
        N3["노드N: OTel Agent"]
        GW["OTel Gateway<br/>Deployment 2~3개"]
        N1 --> GW
        N2 --> GW
        N3 --> GW
    end
    GW -->|"중앙으로 전송"| MGMT["mgmt 저장 계층"]
```

---

## 다이어그램 4: Gateway 내부의 신호별 파이프라인 분기

```mermaid
flowchart LR
    IN["OTLP 수신<br/>4317 / 4318<br/>(3대 신호 공용)"]
    IN --> P1["logs 파이프라인"]
    IN --> P2["traces 파이프라인"]
    IN --> P3["metrics 파이프라인"]
    P1 --> VL["VictoriaLogs"]
    P2 --> VT["VictoriaTraces"]
    P3 --> VM["VictoriaMetrics"]
```

---

## 다이어그램 5: mgmt 저장 계층 상세 (VictoriaMetrics 생태계)

```mermaid
flowchart LR
    OT["OTel Gateway"]
    OT -->|"/insert/.../logs"| VMA["vmauth :8427<br/>진입점 / LB / 인증"]
    OT -->|"/insert/.../traces"| VMA
    VMA --> VLI["vlinsert"] --> VLS["vlstorage"]
    VMA --> VTI["vtinsert"] --> VTS["vtstorage"]
    OT -->|"OTLP / Prometheus"| VMI["vminsert"] --> VMS["vmstorage"]
    VLSEL["vlselect"] --> VLS
    VTSEL["vtselect"] --> VTS
    VMSEL["vmselect"] --> VMS
    GF["Grafana"] --> VMA
    GF --> VMSEL
```

---

## 다이어그램 6: 멀티클러스터 중앙집중 토폴로지

```mermaid
flowchart LR
    subgraph DEV["dev"]
        GD["Gateway<br/>env=dev"]
    end
    subgraph STG["stg"]
        GS["Gateway<br/>env=stg"]
    end
    subgraph PROD["prod"]
        GP["Gateway<br/>env=prod"]
    end
    subgraph MGMT["mgmt (중앙)"]
        VMA["vmauth :8427"]
        STORE["VictoriaLogs / Traces / Metrics"]
        GF["Grafana"]
        VMA --> STORE
        GF --> STORE
    end
    GD -->|"TLS + 인증"| VMA
    GS -->|"TLS + 인증"| VMA
    GP -->|"TLS + 인증"| VMA
```

---

## 다이어그램 7: trace_id 기반 신호 상관관계

```mermaid
flowchart TB
    APP["앱 (계측됨)<br/>trace_id 공유"]
    APP -->|"로그에 trace_id 포함"| VL["VictoriaLogs<br/>로그"]
    APP -->|"트레이스"| VT["VictoriaTraces<br/>트레이스"]
    APP -->|"메트릭"| VM["VictoriaMetrics<br/>메트릭"]
    VL <-->|"trace_id 링크"| VT
    VT <-->|"서비스 그래프"| VM
    GF["Grafana 한 화면"]
    GF --- VL
    GF --- VT
    GF --- VM
```

---

## 다이어그램 8: 고급 요소를 포함한 최종 통합 구성도

```mermaid
flowchart LR
    subgraph CLUSTERS["dev / stg / prod"]
        AGT["OTel Agent<br/>(DaemonSet)"]
        GWY["OTel Gateway<br/>(샘플링 적용)"]
        AGT --> GWY
    end
    subgraph MGMT["mgmt 클러스터"]
        direction TB
        VMA["vmauth :8427<br/>멀티테넌시 / 인증"]
        VL["VictoriaLogs"]
        VT["VictoriaTraces"]
        VM["VictoriaMetrics"]
        ALERT["vmalert → AlertManager"]
        GF["Grafana"]
        VMA --> VL
        VMA --> VT
        VMA --> VM
        VL --> ALERT
        VM --> ALERT
        VL --> GF
        VT --> GF
        VM --> GF
    end
    GWY -->|"TLS + 인증<br/>로그·트레이스·메트릭"| VMA
```
