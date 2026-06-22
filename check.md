상사분이나 팀 내에 기술적으로 투명하고 상세하게 보고하실 수 있도록, **사용된 명령어, 구체적인 에러 로그 내용, 인프라 메커니즘, 그리고 단계별 대체 방안**까지 모두 포함한 **최종 상세 기술 보고서**를 Markdown 형식으로 작성했습니다.
이 내용을 그대로 복사하여 보고서 양식이나 .md 파일로 저장해 활용하시기 바랍니다.
```markdown
# [상세 기술 보고서] 신규 K8s 클러스터 모니터링 시스템 구축 및 로그 수집 파이프라인 검증 경과

## 1. 개요
본 보고서는 신규 구축된 Kubernetes(K8s) 클러스터 환경에서 Grafana 플러그인(VictoriaLogs) 설치 및 OpenTelemetry(Otel) 기반의 전사 로그 수집 파이프라인을 구축하는 과정에서 진행된 상세 기술 테스트 내역과 클러스터 인프라적 제약 사항(보안 및 자동화 정책), 그리고 이를 우회하기 위한 단기/장기 기술적 대체 방안을 공유하기 위해 작성되었습니다.

---

## 2. Grafana 및 VictoriaLogs 플러그인 수동 설치 검증

### ① 기술 테스트 및 실행 명령어
현 시스템의 Grafana 파드가 다중 컨테이너 구조로 동작함을 파악하고, 메인 애플리케이션 컨테이너에 플러그인 파일을 수동 배포했습니다.

```bash
# 1. Grafana 파드 내 컨테이너 구조 확인
kubectl get pods -n <네임스페이스> <grafana-파드이름> -o jsonpath='{.spec.containers[*].name}'
# 출력 결과: grafana-sc-dashboard grafana-sc-datasources grafana

# 2. 메인 컨테이너(-c grafana)의 플러그인 디렉토리로 압축 해제된 파일 복사
kubectl cp ./victoriametrics-logs-datasource <네임스페이스>/<grafana-파드이름>:/var/lib/grafana/plugins/ -c grafana

# 3. 파일 복사 여부 컨테이너 내부 검증
kubectl exec -it <grafana-파드이름> -c grafana -n <네임스페이스> -- ls -l /var/lib/grafana/plugins/

```
### ② 발생한 이슈 및 블로킹 요소
 * **현상**: 파일 복사 후 Grafana 웹 UI의 데이터소스(Datasource) 목록에서 VictoriaLogs가 인식되지 않음.
 * **상세 에러 로그 (kubectl logs 확인 결과)**:
   ```text
   logger=plugins.initialization t=2026-06-22T14:00:00.00Z level=error msg="Could not start plugin backend" pluginId=victoriametrics-logs-datasource error="permission denied"
   
   ```
 * **원인 분석**: 로컬 PC 환경(Windows/macOS)에서 플러그인 압축을 풀고 kubectl cp를 통해 리눅스 컨테이너 내부로 복사하는 과정에서, 백엔드 바이너리 실행에 필수적인 **리눅스 실행 권한(+x)이 유실**되었습니다. 이로 인해 Grafana 프로세스가 파일 권한 거부(Permission Denied)로 플러그인 로드에 실패했습니다.
### ③ 임시 조치 및 근본 해결 방안
 * **임시 조치 (권한 강제 부여)**:
   ```bash
   kubectl exec -it <grafana-파드이름> -c grafana -n <네임스페이스> -- chmod -R 755 /var/lib/grafana/plugins/victoriametrics-logs-datasource
   
   ```
   *(※ 주의: 현재 구조가 영구 볼륨(PVC) 마운트가 아닐 경우, 파드 재시작 시 해당 권한 및 파일이 초기화될 수 있음)*
 * **근본 해결 방안**: 인프라의 안정적인 운영을 위해 배포 시점에 권한이 교정된 **커스텀 Docker 이미지 빌드 방식**으로 전환합니다.
   ```dockerfile
   FROM grafana/grafana:10.x.x
   USER root
   COPY ./victoriametrics-logs-datasource /var/lib/grafana/plugins/victoriametrics-logs-datasource
   RUN chmod -R 755 /var/lib/grafana/plugins/victoriametrics-logs-datasource && \
       chown -R grafana:grafana /var/lib/grafana/plugins/victoriametrics-logs-datasource
   USER grafana
   
   ```
## 3. 신규 OpenTelemetry Agent (DaemonSet) 설치 시도
### ① 기술 테스트 및 실행 명령어
노드 단위의 파일 스크래핑 방식으로 클러스터 내 전체 파드의 로그를 통합 수집하기 위해, Helm 및 Manifest를 통해 OpenTelemetry Agent를 DaemonSet 형태로 배포를 시도했습니다.
```bash
# Otel Agent Helm 차트 설치 시도
helm install otel-agent open-telemetry/opentelemetry-collector -f values.yaml -n <네임스페이스>

```
### ② 발생한 이슈 및 블로킹 요소 (인프라 보안 정책 차단)
배포 시 클러스터 보안 가드레일인 **Kyverno(또는 OPA Gatekeeper)** 어드미션 웹훅에 의해 파드 생성이 거부되었습니다.
 * **1차 차단 (hostPort 정책 위반)**:
   * 에이전트가 노드의 특정 포트를 직접 바인딩하려는 hostPort: 4317 설정이 보안 취약점(포트 충돌 및 호스트 네트워크 노출 위험)으로 감지되어 Kyverno 정책에 의해 거부됨.
 * **2차 차단 (hostPath 정책 위반)**:
   * hostPort 설정을 제거하고 로그 수집 프리셋(presets.logsCollection.enabled=true)을 활성화하자, 파드가 노드의 실제 로그 디렉토리(/var/log/pods)를 읽기 위해 내부적으로 **hostPath 볼륨 마운트**를 생성함.
   * Kyverno의 **Pod Security Standards (PSS) - Baseline/Restricted** 규정에 따라, 컨테이너가 노드 파일 시스템에 직접 접근하는 hostPath 사용이 원천 차단되어 파드 배포가 실패함.
```bash
# 에러 확인 명령어
kubectl get events -n <네임스페이스> --sort-by='.metadata.creationTimestamp'
# 에러 메시지 예시: admission webhook "validate.kyverno.svc-fail" denied the request: hostPath volumes are not allowed / hostPort is not allowed.

```
## 4. 기설치 플랫폼 공용 Otel-agent 수동 수정 시도
### ① 기술 테스트 및 실행 명령어
새로운 에이전트 배포가 보안 정책으로 막힘에 따라, 시스템 플랫폼 레벨에 이미 사전 설치되어 정상 구동 중인 공용 otel-agent를 활용하는 방향으로 전환했습니다. 공용 에이전트가 수집한 데이터를 당사가 구축한 otel-gateway로 복제 전송(멀티 라우팅)하도록 ConfigMap 수정을 시도했습니다.
```bash
# 1. 공용 Otel-Agent의 ConfigMap 수동 수정
kubectl edit cm <공용-otel-agent-configmap-이름> -n <네임스페이스>

```
**[수정 시도한 설정 내역 (config.yaml)]**
```yaml
exporters:
  otlp/smap: # 당사 Gateway 목적지 명명 (명칭은 자유롭게 지정 가능)
    endpoint: "my-otel-gateway-service.your-namespace.svc.cluster.local:4317"
    tls:
      insecure: true
service:
  pipelines:
    logs:
      exporters: [logging, otlp/smap] # 기존 목적지에 당사 목적지 추가

```
```bash
# 2. 변경 설정 반영을 위한 데몬셋 롤링 재시작
kubectl rollout restart daemonset/<공용-otel-agent-데몬셋-이름> -n <네임스페이스>

```
### ② 발생한 이슈 및 블로킹 요소 (자동화 동기화 루프의 벽)
 * **현상**: ConfigMap을 수정하고 재시작을 처리했으나, **수 분 이내에 수정 내역이 사라지고 기존 원본 설정으로 강제 원상복구(Reversion)**되는 현상 발생.
 * **원인 분석**: 해당 클러스터의 인프라가 **GitOps 도구(ArgoCD 또는 Flux)**에 의해 관리되거나, **OpenTelemetry Operator**의 제어를 받고 있음이 확인되었습니다. 이 시스템들은 수동 변경 사항을 '상태 틀어짐(Drift)'으로 인식하여, 형상 관리 저장소(Git)의 원본 상태로 강제 동기화(Reconciliation)를 무한 반복하므로 수동 우회가 불가능합니다.
## 5. 향후 구체적 대체 방안
현재 신규 클러스터의 엄격한 **보안 정책(Kyverno)**과 형상 관리 **자동화 시스템(GitOps)**으로 인해 인프라 레벨의 수동 개입은 불가능합니다. 따라서 다음과 같은 단계적 우회 및 정공법을 제안합니다.
### 💡 대체 방안 A: 애플리케이션 레벨 직접 Push (단기 우회 - 즉시 검증 가능)
인프라의 파일 시스템 접근 제약(hostPath)을 받지 않도록, 애플리케이션 소스코드 또는 로그 프레임워크 단에서 네트워크 프로토콜(OTLP)을 통해 직접 당사의 otel-gateway로 로그를 밀어 넣는 방식입니다.
 * **기술적 구현 매커니즘**:
   1. 애플리케이션 내부(예: Spring Boot의 Logback, Node.js의 Winston 등)에 OpenTelemetry gRPC/HTTP Appender를 라이브러리로 추가합니다.
   2. 로그의 엔드포인트를 당사가 구축한 Gateway 서비스 주소로 바라보게 설정합니다.
   3. K8s 서비스 명세에 internalTrafficPolicy: Local 설정을 적용하여, 트래픽이 타 노드로 유실되지 않고 동일 노드 내의 Gateway 파드로 최단 거리 통신이 이루어지도록 최적화합니다.
```yaml
# Gateway 내부 수신 구조 예시 (values.yaml)
config:
  receivers:
    otlp: # 포트 4317 자동 오픈, 에이전트 단의 이름과 무관하게 OTLP 표준 수신
      protocols:
        grpc:
  exporters:
    otlphttp/victoria-logs: # 최종 목적지인 VictoriaMetrics로 라우팅
      endpoint: "http://victoria-logs-single-server:9428/v1/push/write"
  service:
    pipelines:
      logs:
        receivers: [otlp]
        processors: [batch]
        exporters: [otlphttp/victoria-logs]

```
 * **장점**: 인프라 팀의 권한 승인을 기다릴 필요 없이 개발 팀 권한으로 즉시 파이프라인 전체(App -> Gateway -> Victoria -> Grafana)를 테스트하고 검증할 수 있습니다.
### 💡 대체 방안 B: 사이드카(Sidecar) 패턴 배포 (중기 대안)
애플리케이션 코드를 수정할 수 없는 상황이라면, Pod 배포 정의서(Deployment.yaml)를 수정하여 앱 컨테이너 옆에 가벼운 수집기 컨테이너를 한 지붕 아래 같이 띄우는 방식입니다.
 * **기술적 구현 매커니즘**:
   1. Kyverno 정책이 허용하는 emptyDir 볼륨을 생성하여 두 컨테이너가 공유합니다.
   2. 앱 컨테이너는 로그를 콘솔이 아닌 해당 공유 볼륨의 파일로 씁니다.
   3. 사이드카로 구성된 otel-collector 컨테이너가 해당 파일을 읽어 당사 Gateway로 전송합니다.
 * **장점**: 클러스터 전체 권한이 필요 없으며 수동 로그 긁기 방식의 장점을 유지할 수 있습니다.
### 💡 대체 방안 C: 플랫폼 운영 팀과의 협의 및 GitOps 반영 (장기 정공법)
검증 완료 후, 수백~수천 개의 전사 서비스를 수용하기 위한 최종 운영 단계입니다.
 * **기술적 구현 매커니즘**:
   1. 단기 우회 테스트를 통해 안정성이 입증된 수집 설정을 기반으로 플랫폼 팀에 정식 요청을 진행합니다.
   2. 플랫폼 팀이 관리하는 **공용 에이전트의 원본 Git 리포지토리 설정 파일**에 당사 전용 Gateway 주소(otlp/my-gateway)를 Exporter 및 파이프라인에 영구 등록하는 Pull Request(PR)를 제출합니다.
 * **장점**: 전사 시스템의 추가적인 리소스 낭비(사이드카 오버헤드 등) 없이, 기존에 잘 도는 공용 인프라 에이전트의 멀티 라우팅 기능을 활용해 가장 깔끔하고 대규모 환경에 적합한 표준 아키텍처를 완성할 수 있습니다.
```

```
