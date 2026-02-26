#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#define N 7
#define DEFAULT_PORT 8080
#define REQUEST_BUF_SIZE 2048
#define METRICS_BUF_SIZE 2048

struct metrics_state {
    unsigned long long iterations_total;
    unsigned long long equal_condition_total;
    int zero_above_main;
    int positive_below_secondary;
    double last_run_timestamp_seconds;
};

static struct metrics_state g_metrics = {0};

static void fill_matrix(int matrix[N][N]) {
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            matrix[i][j] = rand() % 19 - 9;
        }
    }
}

static void print_matrix(int matrix[N][N]) {
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            printf("%3d ", matrix[i][j]);
        }
        printf("\n");
    }
}

static void count_matrix_values(int matrix[N][N], int *zeros, int *positives) {
    *zeros = 0;
    *positives = 0;
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            if (j > i && matrix[i][j] == 0) {
                (*zeros)++;
            }
            if (i + j > N - 1 && matrix[i][j] > 0) {
                (*positives)++;
            }
        }
    }
}

static void zero_matrix(int matrix[N][N]) {
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            matrix[i][j] = 0;
        }
    }
}

static void run_single_shot(void) {
    int matrix[N][N];
    int zero_above_main;
    int pos_below_side;

    fill_matrix(matrix);
    printf("Initial matrix:\n");
    print_matrix(matrix);

    count_matrix_values(matrix, &zero_above_main, &pos_below_side);
    if (zero_above_main == pos_below_side) {
        zero_matrix(matrix);
    }

    printf("\nZeros above main diagonal: %d\n", zero_above_main);
    printf("Positive below secondary diagonal: %d\n", pos_below_side);
    printf("\nResult matrix:\n");
    print_matrix(matrix);
}

static void run_metrics_iteration(void) {
    int matrix[N][N];
    int zeros;
    int positives;

    fill_matrix(matrix);
    count_matrix_values(matrix, &zeros, &positives);

    g_metrics.iterations_total++;
    g_metrics.zero_above_main = zeros;
    g_metrics.positive_below_secondary = positives;
    if (zeros == positives) {
        g_metrics.equal_condition_total++;
    }
    g_metrics.last_run_timestamp_seconds = (double)time(NULL);
}

static int parse_port(const char *value) {
    char *endptr = NULL;
    long parsed = strtol(value, &endptr, 10);
    if (endptr == value || *endptr != '\0' || parsed < 1 || parsed > 65535) {
        return -1;
    }
    return (int)parsed;
}

static int send_all(int fd, const char *buffer, size_t length) {
    size_t sent = 0;
    while (sent < length) {
        ssize_t written = send(fd, buffer + sent, length - sent, 0);
        if (written < 0) {
            return -1;
        }
        sent += (size_t)written;
    }
    return 0;
}

static int send_http_response(int client_fd, const char *status, const char *type, const char *body) {
    char header[512];
    int body_len = (int)strlen(body);
    int header_len = snprintf(
        header,
        sizeof(header),
        "HTTP/1.1 %s\r\n"
        "Content-Type: %s\r\n"
        "Content-Length: %d\r\n"
        "Connection: close\r\n"
        "\r\n",
        status,
        type,
        body_len
    );
    if (header_len < 0 || (size_t)header_len >= sizeof(header)) {
        return -1;
    }
    if (send_all(client_fd, header, (size_t)header_len) != 0) {
        return -1;
    }
    return send_all(client_fd, body, (size_t)body_len);
}

static void handle_http_client(int client_fd) {
    char request[REQUEST_BUF_SIZE];
    ssize_t read_size = recv(client_fd, request, sizeof(request) - 1, 0);
    if (read_size <= 0) {
        return;
    }
    request[read_size] = '\0';

    if (strncmp(request, "GET /healthz", 12) == 0) {
        (void)send_http_response(client_fd, "200 OK", "text/plain; charset=utf-8", "ok\n");
        return;
    }

    if (strncmp(request, "GET /metrics", 12) == 0) {
        char metrics[METRICS_BUF_SIZE];
        int metrics_len;

        run_metrics_iteration();
        metrics_len = snprintf(
            metrics,
            sizeof(metrics),
            "# HELP reverse_iterations_total Total matrix iterations.\n"
            "# TYPE reverse_iterations_total counter\n"
            "reverse_iterations_total %llu\n"
            "# HELP reverse_equal_condition_total Iterations where both counters are equal.\n"
            "# TYPE reverse_equal_condition_total counter\n"
            "reverse_equal_condition_total %llu\n"
            "# HELP reverse_zero_above_main Current zeros above main diagonal.\n"
            "# TYPE reverse_zero_above_main gauge\n"
            "reverse_zero_above_main %d\n"
            "# HELP reverse_positive_below_secondary Current positives below secondary diagonal.\n"
            "# TYPE reverse_positive_below_secondary gauge\n"
            "reverse_positive_below_secondary %d\n"
            "# HELP reverse_last_run_timestamp_seconds Last iteration timestamp.\n"
            "# TYPE reverse_last_run_timestamp_seconds gauge\n"
            "reverse_last_run_timestamp_seconds %.0f\n",
            g_metrics.iterations_total,
            g_metrics.equal_condition_total,
            g_metrics.zero_above_main,
            g_metrics.positive_below_secondary,
            g_metrics.last_run_timestamp_seconds
        );
        if (metrics_len < 0 || (size_t)metrics_len >= sizeof(metrics)) {
            (void)send_http_response(
                client_fd,
                "500 Internal Server Error",
                "text/plain; charset=utf-8",
                "metrics buffer overflow\n"
            );
            return;
        }
        (void)send_http_response(client_fd, "200 OK", "text/plain; version=0.0.4", metrics);
        return;
    }

    (void)send_http_response(client_fd, "404 Not Found", "text/plain; charset=utf-8", "not found\n");
}

static int run_server(int port) {
    int server_fd;
    int reuse = 1;
    struct sockaddr_in address;

    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("socket");
        return 1;
    }

    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse)) < 0) {
        perror("setsockopt");
        close(server_fd);
        return 1;
    }

    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_ANY);
    address.sin_port = htons((unsigned short)port);

    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        perror("bind");
        close(server_fd);
        return 1;
    }

    if (listen(server_fd, 16) < 0) {
        perror("listen");
        close(server_fd);
        return 1;
    }

    printf("reverse server listening on port %d\n", port);
    fflush(stdout);

    for (;;) {
        int client_fd = accept(server_fd, NULL, NULL);
        if (client_fd < 0) {
            if (errno == EINTR) {
                continue;
            }
            perror("accept");
            break;
        }
        handle_http_client(client_fd);
        close(client_fd);
    }

    close(server_fd);
    return 1;
}

static void print_usage(const char *program) {
    fprintf(
        stderr,
        "Usage: %s [--server] [--port <1-65535>]\n"
        "  default mode: run one matrix calculation and exit\n"
        "  --server: run HTTP server with /healthz and /metrics\n",
        program
    );
}

int main(int argc, char **argv) {
    int server_mode = 0;
    int port = DEFAULT_PORT;
    const char *env_port = getenv("APP_PORT");

    if (env_port != NULL && env_port[0] != '\0') {
        int parsed = parse_port(env_port);
        if (parsed < 0) {
            fprintf(stderr, "Invalid APP_PORT value: %s\n", env_port);
            return 1;
        }
        port = parsed;
    }

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--server") == 0) {
            server_mode = 1;
            continue;
        }
        if (strcmp(argv[i], "--port") == 0) {
            if (i + 1 >= argc) {
                fprintf(stderr, "--port requires a value\n");
                print_usage(argv[0]);
                return 1;
            }
            i++;
            port = parse_port(argv[i]);
            if (port < 0) {
                fprintf(stderr, "Invalid port: %s\n", argv[i]);
                return 1;
            }
            continue;
        }
        if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            print_usage(argv[0]);
            return 0;
        }
        fprintf(stderr, "Unknown argument: %s\n", argv[i]);
        print_usage(argv[0]);
        return 1;
    }

    srand((unsigned int)time(NULL));
    if (server_mode) {
        return run_server(port);
    }

    run_single_shot();
    return 0;
}
