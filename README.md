# B3-1 · AWS 기초 웹 인프라 구축

서울 리전의 VPC 안에 Public Subnet과 EC2/Nginx 웹 서버를 구성했습니다. HTTP는 공개하고 SSH는 운영자 IP로 제한했으며, 설정 확인·외부 응답·서버 access log로 동작을 확인했습니다.

**이 프로젝트가 만드는 것:** 다른 사람도 접속할 수 있는 웹 서버와, 그 서버에 도달하는 네트워크·접근 제어 환경입니다.

**현재 상태:** 배포 및 핵심 통신 확인. IAM 연결 정책·본문·그룹 소속 확인을 마쳤으며 주요 AWS 실습 자원의 삭제와 재조회를 마쳤습니다. 로컬 개인키 삭제와 Billing 사용자 확인(표시 내역 없음)도 마쳤습니다. 제출 규격·문서 링크·공개 전 민감정보 점검까지 완료했습니다.

## 여기서 시작하세요

| 확인할 내용 | 바로 보기 |
| --- | --- |
| 서비스 구조와 용어 | [아키텍처](docs/images/architecture.png) · [설계 설명](docs/architecture-design.md) · [Glossary](docs/glossary.md) |
| 외부에서 실제 응답하는가? | [접속 화면](docs/images/external-health.png) |
| 서버 내부도 정상인가? | [서버 검증 로그](evidence/server/20261021T192610Z-fecfd7c3/verification.log) |
| 오류를 어떻게 해결했는가? | [트러블슈팅 보고서 — IAM 조회 권한 누락 1건](docs/troubleshooting.md) |
| 정리 완료 여부 | [리소스 정리 체크리스트](docs/cleanup-checklist.md) |

## 1. 아키텍처와 요청 흐름

![AWS 웹 서비스 아키텍처](docs/images/architecture.png)

다이어그램은 설계 설명용 v3입니다. 실제 배포 자원 ID는 [추적 기록](docs/cleanup-checklist.md)에 있습니다. EC2·EBS를 1개씩 사용한 단일 AZ 실습 구성입니다.

| 흐름 | 경로 | 의미 |
| --- | --- | --- |
| 웹 요청 | 방문자 → 인터넷 → IGW → EC2 ENI의 SG 검사 → Nginx :80 | 공개한 웹 서비스에 접근 |
| 웹 응답 | Nginx → EC2 ENI → Subnet의 기본 라우트 → IGW → 방문자 | 요청에 대한 페이지 또는 OK 반환 |
| 서버 관리 | 운영자 → IGW → SG의 IP 제한 → sshd :22 | 개인키로 SSH 로그인 |
| 서버 외부 통신 | EC2 → SG 아웃바운드 → 기본 라우트 → IGW → 외부 서비스 | 패키지 다운로드 및 외부 HTTPS 요청 |

IGW는 VPC에 연결합니다. Route Table은 Subnet에 연결해 경로를 정하며, 별도의 중계 서버가 아닙니다. SG는 서버의 네트워크 통신을, IAM은 AWS API 작업 권한을 제어합니다.

## 2. 실제 구성

| 자원 | 설정 |
| --- | --- |
| VPC | `10.0.0.0/16` |
| Public Subnet | `10.0.1.0/24`, `ap-northeast-2a` |
| IGW | 실습 VPC에 연결 |
| Route Table | 내부 `local`, 기본 경로 `0.0.0.0/0 → IGW`, 실습 Subnet 명시적 연결 |
| EC2 | Amazon Linux 2023, `t3.micro`, 퍼블릭 IPv4, 실습 Subnet·SG 적용 |
| EBS | gp3 8 GiB, `DeleteOnTermination=true` |
| SG | 인바운드 TCP 80 전체 IPv4, TCP 22 운영자 공인 IP `/32`; 아웃바운드 전체 IPv4 |
| Nginx | `/` 웹페이지, `/health`는 200과 `OK` |
| IAM | 실습용 IAM 사용자 `b3-1-lab`; 서울 리전 작업, EC2 유형 제한 |

관리자 콘솔의 연결 정책 목록에서 B3-1-Seoul-Lab·IAMUserChangePassword·SignInLocalDevelopmentAccess 3개와 관리자 정책이 목록에 없음을 확인했습니다. 사용자가 콘솔에서 복사한 적용 정책과 [정책 코드](infra/iam-policy.json)의 내용이 일치함을 확인했습니다. 그룹 소속 화면에서 소속 그룹이 없음을 확인했습니다. `Resource: "*"`인 작업이 있어 실습 태그만으로 권한이 격리되는 정책은 아닙니다.

실제 EC2에는 현재 `Name` 태그가 없고 `Project=b3-1`만 있습니다. 이름 검색 대신 기록한 ID로 추적합니다. 실습 자원에 붙인 프로젝트 태그와 ID를 함께 사용하고 기존 공모전 자원은 정리 대상에서 제외합니다.

## 3. 외부 접속 검증 — 방식 B

- 선택한 방식: **B — 외부 GET /health**
- 검증 당시 URL: **http://52.79.255.16/health**
- 결과: **HTTP 200**, 고정 응답 **`OK`**
- 이 주소는 실습 당시 주소입니다. 정리 후에는 접속되지 않는 것이 정상입니다.

![브라우저 주소창과 OK 응답](docs/images/external-health.png)

**보조 확인 — 메인 페이지:** `http://52.79.255.16/`에서도 Nginx가 제공하는 Hello Cloud 페이지가 표시됩니다. 기본 검증 방식은 B로 유지하며, 아래 사진은 웹페이지 표시 결과를 추가로 보여줍니다.

![외부 브라우저에서 열린 Hello Cloud 페이지](docs/images/external-home.png)


**Nginx는 브라우저의 HTTP 요청을 받아 웹페이지나 응답을 보내는 웹 서버 프로그램입니다.** `Welcome to nginx!`는 Nginx 설치 직후 제공되는 기본 페이지입니다.

이번 실습에서는 [초기 설정 스크립트](infra/user-data.sh)가 `/usr/share/nginx/html/index.html`을 Hello Cloud 페이지로 교체했습니다. 따라서 Hello Cloud가 보이는 것은 Nginx가 우리가 설정한 HTML 파일을 정상적으로 제공하고 있음을 보여줍니다.

| 요청 경로 | Nginx의 응답 | 확인 목적 |
| --- | --- | --- |
| `/` | Hello Cloud HTML 페이지 | 사용자가 웹페이지를 볼 수 있는지 확인 |
| `/health` | HTTP 200과 고정 본문 `OK` | 서버가 요청에 정상 응답하는지 간단히 확인 |

외부 요청에 `evidence=20261021T190713Z-a002c911`을 붙였습니다. [Nginx access log](evidence/server/20261021T192610Z-fecfd7c3/verification.log)에서 해당 요청의 `status=200`을 확인했습니다. 접속 사진은 별도로 `/health`의 OK 응답을 보여줍니다.

| 검증 항목 | 실제 결과 |
| --- | --- |
| SSH 로그인 | Amazon Linux 로그인 배너와 `ec2-user` 프롬프트 확인 |
| Nginx 프로세스 | `systemctl is-active nginx` → `active` |
| 내부 웹 요청 | `curl http://localhost/` → `HTTP/1.1 200 OK` |
| 서버의 외부 통신 | `https://example.com` → HTTP 200, curl 종료 코드 0 |
| 외부 요청 처리 | 동일 evidence 값의 access log, `status=200` |

[서버 검증 로그](evidence/server/20261021T192610Z-fecfd7c3/verification.log)에는 Nginx 실행 상태·내부 HTTP 200·외부 통신 성공·외부 요청 처리 결과만 발췌했습니다. 전체 원본 로그가 아니며, 명령 표기는 실행 맥락을 설명하기 위해 추가했습니다. SSH 접속 후 확보한 출력이고 검증 시각은 2026-10-21 19:18:27 UTC입니다. UTC에 9시간을 더하면 한국 시간입니다.

## 4. 평가 질문에 대한 설명

IAM 정책은 EC2/VPC 작업을 열거하고 서울 리전 조건을 적용했으며, t2.micro·t3.micro 이외의 인스턴스 실행을 거부합니다. S3·RDS·IAM 관리 권한은 부여하지 않았습니다. 다만 `Resource: "*"`이므로 프로젝트별 자원 격리를 강제하지 않으며, 인스턴스 수·EBS 용량·SG 포트도 정책 자체가 제한하지는 않습니다.

아래는 평가 기준에 맞춰 정리한 17개 질문과 답변입니다. 상황 대응 질문은 설계 설명이며 실제 확장·장애 실험을 수행했다는 뜻은 아닙니다.

### 항목 1 · 실제 구성과 결과

| 질문 | 답변과 근거 |
| --- | --- |
| 1. 네트워크가 구성됐는가? | VPC·Subnet·IGW를 만들고, Subnet에 연결된 Route Table의 기본 경로를 IGW로 설정했습니다. 구축 후 설정 확인 |
| 2. SSH와 웹 서버가 동작하는가? | 개인키로 로그인했고 Nginx active와 내부 HTTP 200을 확인했습니다. [서버 결과](evidence/server/20261021T192610Z-fecfd7c3/verification.log) |
| 3. 필요한 포트만 허용했는가? | 웹용 80만 전체 공개하고 관리용 22는 운영자 IP 하나로 제한했습니다. 구축 후 설정 확인 |
| 4. 외부 접속이 검증됐는가? | 방식 B를 선택해 외부 /health의 200과 OK를 확인했습니다. [접속 화면](docs/images/external-health.png) |
| 5. 최소 5종 자원이 정리됐는가? | **주요 자원 확인 완료.** EC2 terminated, EBS·IGW·VPC 삭제 및 EIP 없음 확인. 로컬 개인키 삭제와 Billing 사용자 확인도 마쳤습니다. [정리 기준](docs/cleanup-checklist.md) |

### 항목 2 · 설계 선택

| 질문 | 답변과 근거 |
| --- | --- |
| 6. 요청 흐름을 설명할 수 있는가? | 방문자가 퍼블릭 IP로 요청하면 IGW를 거쳐 SG가 허용한 EC2의 Nginx에 도달합니다. 응답은 Subnet 기본 경로와 같은 IGW를 사용합니다. [설계도](docs/images/architecture.png) |
| 7. SG 최소화 기준은 무엇인가? | 실제 사용하는 HTTP·SSH만 열고 불필요한 DB 포트 등은 열지 않았습니다. SSH 허용 IP와 키 인증은 별도 조건입니다. |
| 8. A/B 중 왜 B인가? | 고정된 상태 코드와 본문을 자동 검사하고 access log와 연결하기 쉽기 때문입니다. Nginx에 /health를 설정했습니다. [스크립트](infra/user-data.sh) |
| 9. 자원을 어떻게 추적하는가? | Project=b3-1과 자원별 이름·실제 ID 목록을 대조합니다. 기본 자동 생성 자원도 기록합니다. [추적 기록](docs/cleanup-checklist.md) |

### 항목 3 · 원리와 보안

| 질문 | 답변과 근거 |
| --- | --- |
| 10. 기본 라우트는 왜 필요한가? | 더 구체적인 경로가 없는 외부 IPv4 목적지를 IGW로 보내기 위해 필요합니다. VPC 내부는 local 경로가 우선합니다. |
| 11. SG와 IAM은 어떻게 다른가? | SG는 서버 통신 허용, IAM은 AWS API 작업 허용입니다. 각각 필요한 범위만 열어 불필요한 접근과 작업을 줄입니다. |
| 12. SSH·DB 전체 공개의 대안은? | 공격 가능한 접근 범위를 줄이기 위해 SSH는 운영자 IP로 제한합니다. DB가 필요하다면 사설 Subnet에 두고 필요한 애플리케이션 SG에서만 접근하도록 설계합니다. DB는 이번에 만들지 않았습니다. |
| 13. 가설 후 검증하는 이유는? | 여러 설정을 동시에 바꾸면 원인을 구분할 수 없습니다. 이번에는 오류 API와 정책을 대조한 뒤 Action 하나만 추가하고 동일 API를 재검증했습니다. [단일 트러블슈팅 사례](docs/troubleshooting.md) |

### 항목 4 · 상황 대응

| 질문 | 답변 |
| --- | --- |
| 14. 외부 접속이 안 되면? | 라우팅의 IGW 연결·기본 경로·Subnet 연결 → 실제 EC2 SG → 퍼블릭 IP/DNS → 프로세스·리스닝·서버 로그 순서로 확인합니다. 요청이 HTTP인지 HTTPS인지도 먼저 구분합니다. |
| 15. IAM 권한이 부족하면? | 실제 호출자와 실패한 Action·Resource·조건을 확인하고 Allow 누락 또는 Deny 여부를 대조합니다. 필요한 범위만 수정하고 같은 사용자로 같은 API를 재실행합니다. |
| 16. 서버를 2대로 늘리려면? | 단일 EC2의 CPU·메모리·응답시간을 측정해 병목을 확인합니다. ALB와 대상 그룹으로 요청을 분산하고, 고가용성이 필요하면 2개 AZ에 배치합니다. 자동 증설은 Auto Scaling을 검토하고 세션·파일의 서버 종속성도 확인합니다. 실제 추가 생성은 하지 않았습니다. |
| 17. 예상치 못한 비용이 생기면? | Billing에서 서비스·리전·사용 유형을 확인하고 EC2·EBS·퍼블릭 IPv4/EIP부터 추적합니다. 생성했다면 NAT Gateway·ALB·스냅샷도 확인합니다. 실습 ID와 태그를 대조해 정리하고 잔여 자원을 재조회합니다. |

## 5. 실행 환경과 확인 방법

로컬은 Windows PowerShell, AWS CLI v2, OpenSSH를 사용합니다. 서버는 Amazon Linux 2023이며 SSH 로그인 이름은 `ec2-user`입니다. 이번 구축은 콘솔로 수행했고 `user-data.sh`는 첫 부팅 시 Nginx를 초기 설정하는 데 사용했습니다. 인프라 전체 자동 배포를 구현했다고 주장하지 않습니다.

```powershell
# CLI 인증 후 실제 사용자 확인
aws sts get-caller-identity --profile b3-1-lab --region ap-northeast-2

# 외부 HTTP 검증
curl.exe -i http://52.79.255.16/health

# 개인키는 저장소 밖의 실제 보관 위치 사용
ssh -i "$env:USERPROFILE\Desktop\b3-1-key.pem" ec2-user@52.79.255.16
```

서버에서 실행한 주요 확인 명령:

```bash
systemctl is-active nginx
curl --fail -i http://localhost/
curl --fail --silent --output /dev/null --write-out 'HTTP %{http_code}\n' https://example.com
sudo grep -F 'evidence=20261021T190713Z-a002c911' /var/log/nginx/access.log
```


## 6. 제출 전 남은 작업

- [x] 서버 검증 결과를 제출용 발췌 로그로 정리
- [x] 관리자 콘솔 증빙으로 b3-1-lab의 실제 정책·연결 정책 3개·그룹 없음 확인
- [x] EC2 Name 태그 누락을 명시하고 실제 ID 기준 추적 방식을 문서에 유지
- [x] 설계 다이어그램과 실제 구성 최종 대조
- [x] [정리 체크리스트](docs/cleanup-checklist.md)에 주요 AWS 자원 삭제와 재조회 근거 기록
- [x] 로컬 개인키 정리
- [x] Billing 최종 확인 — 사용자가 확인한 화면에 내역 없음으로 보고

HTTPS·Docker는 선택 과제이며 현재 기본 제출 범위에 포함하지 않았습니다. 무료 혜택은 계정의 적용 조건을 확인하며 인스턴스 유형만으로 무과금을 보장하지 않습니다. 삭제해도 이미 발생한 비용은 남습니다.

## 7. 전체 프로젝트 구조

```text
3-1/
├─ README.md
├─ .gitignore
├─ docs/
│  ├─ architecture.png             # 제출 규격 호환용 설계도
│  ├─ architecture-design.md        # 설계 설명
│  ├─ troubleshooting.md            # IAM 권한 오류 1건
│  ├─ cleanup-checklist.md           # 정리 대상과 완료 근거
│  ├─ glossary.md                   # 용어 사전
│  └─ images/
│     ├─ architecture.png           # 설계도
│     ├─ external-health.png        # 외부 접속 화면
│     ├─ external-home.png          # 메인 페이지 보조 증빙
│     ├─ troubleshooting-before.png # 오류 화면
│     └─ troubleshooting-policy-edit.png # 정책 수정 화면
├─ infra/
│  ├─ iam-policy.json               # 권한 설정
│  └─ user-data.sh                  # Nginx 초기 설치·설정
└─ evidence/
   └─ server/<실행ID>/verification.log # 서버 검증 로그 1개
```

**제출 규격:** 과제에서 지정한 아키텍처 이미지 경로는 `docs/architecture.png`입니다. README 본문과 설계 설명은 관리가 쉬운 `docs/images/architecture.png`를 링크하며, 두 파일은 같은 이미지입니다. `README.md`와 접속 스크린샷, `docs/troubleshooting.md`, `docs/cleanup-checklist.md`도 유지합니다. 아키텍처 설명 MD와 Glossary도 함께 제공합니다. 증빙은 요구사항을 확인하는 핵심 자료만 남겼습니다.

## 파일 읽는 기준

**이 README가 제출의 시작점**입니다. `docs`는 설명 문서, `infra`는 실제 설정 코드, `evidence`는 핵심 증빙입니다. 트러블슈팅 제출은 IAM 조회 권한 누락 **1건**입니다.

서버 검증 로그는 실습 당시 결과이며 운영자 IP를 `[REDACTED_OPERATOR_IP]`로 가렸습니다. 계정 식별정보가 포함된 조회 JSON은 제출에서 제외하고 설정·검증 결과를 문서에 정리했습니다. 트러블슈팅의 오류·정책 수정 사진 2장은 `docs/images/`에 유지했습니다. 오류 사진은 메시지 영역만 잘라 계정 ID가 있는 주변 화면을 제외했습니다.
