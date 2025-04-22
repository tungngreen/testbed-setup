#!/bin/bash

set -e

REGISTRY="143.248.55.42:5000"

usage() {
    echo "Usage:"
    echo "  $0 list"
    echo "  $0 retag <image:tag> <newtag>"
    echo "  $0 pull <image:tag>"
    echo "  $0 push <image:tag> <manifest.json>"
    echo "  $0 remove <image:tag>"
    exit 1
}

list_images() {
    printf "%-40s %-40s %-15s %-12s %10s\n" "REPOSITORY" "TAG" "IMAGE ID" "CREATED" "SIZE"
        echo "-----------------------------------------------------------------------------------------------------------------------------------"

    REPOS=$(curl -s "http://${REGISTRY}/v2/_catalog" | jq -r '.repositories[]')


    for REPO in $REPOS; do
        TAGS=$(curl -s "http://${REGISTRY}/v2/${REPO}/tags/list" | jq -r '.tags[]?' || true)
        for TAG in $TAGS; do
            MANIFEST=$(curl -s -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
                "http://${REGISTRY}/v2/${REPO}/manifests/${TAG}")

            CONFIG_DIGEST=$(echo "$MANIFEST" | jq -r '.config.digest')
            CONFIG_JSON=$(curl -s "http://${REGISTRY}/v2/${REPO}/blobs/${CONFIG_DIGEST}")
            IMAGE_ID="${CONFIG_DIGEST#sha256:}"
            CREATED=$(echo "$CONFIG_JSON" | jq -r '.created' | cut -dT -f1)
            SIZE=$(echo "$MANIFEST" | jq '[.layers[].size] | add' | numfmt --to=iec --suffix=B)

            # spacing
            printf "%-40s %-40s %-15s %-12s %10s\n" "$REPO" "$TAG" "${IMAGE_ID:0:12}" "$CREATED" "$SIZE"
        done
    done
}

generate_manifest() {
    local IMAGE="${1%%:*}"
    local TAG="${1##*:}"
    local SAFE_IMAGE_TAG=$(echo "${IMAGE}_${TAG}" | sed 's/[\/:]/_/g')
    local OUT="/tmp/${SAFE_IMAGE_TAG}_manifest.json"

    echo "📄 Generating manifest for ${IMAGE}:${TAG}..."
    curl -s -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        "http://${REGISTRY}/v2/${IMAGE}/manifests/${TAG}" \
        -o "$OUT"

    if [ ! -s "$OUT" ]; then
        echo "❌ Failed to retrieve manifest for ${IMAGE}:${TAG}"
        exit 1
    fi

    echo "$OUT"
}


retag_image() {
    [[ $# -ne 2 ]] && usage
    OLD="$1"
    NEW_TAG="$2"
    IMAGE="${OLD%%:*}"
    OLD_TAG="${OLD##*:}"

    MANIFEST_PATH=$(generate_manifest "$IMAGE:$OLD_TAG")

    curl -s -X PUT \
        -H "Content-Type: application/vnd.docker.distribution.manifest.v2+json" \
        --data-binary @"$MANIFEST_PATH" \
        "http://${REGISTRY}/v2/${IMAGE}/manifests/${NEW_TAG}" > /dev/null

    echo "✅ Retagged ${IMAGE}:${OLD_TAG} -> ${IMAGE}:${NEW_TAG}"
}

pull_image() {
    [[ $# -ne 1 ]] && usage
    IMAGE="$1"
    FULL="${REGISTRY}/${IMAGE}"

    echo "📥 Pulling ${FULL}..."
    docker pull "${FULL}" || return 1

    LOCAL_TAG="${IMAGE}"
    echo "🔖 Retagging ${FULL} -> ${LOCAL_TAG}"
    docker tag "${FULL}" "${LOCAL_TAG}"

    echo "🧹 Removing original tag: ${FULL}"
    docker rmi "${FULL}"

    echo "✅ Pulled, retagged as ${LOCAL_TAG}, and cleaned up original"
}

push_image() {
    [[ $# -ne 1 ]] && usage
    IMAGE="$1"
    REMOTE_TAG="${REGISTRY}/${IMAGE}"

    echo "🔖 Tagging ${IMAGE} -> ${REMOTE_TAG}"
    docker tag "${IMAGE}" "${REMOTE_TAG}" || return 1

    echo "🚀 Pushing ${REMOTE_TAG}..."
    docker push "${REMOTE_TAG}" || return 1

    echo "🧹 Removing temporary tag: ${REMOTE_TAG}"
    docker rmi "${REMOTE_TAG}"

    echo "✅ Pushed and cleaned up temporary tag"
}

remove_image() {
    [[ $# -ne 1 ]] && usage
    IMAGE="$1"
    REPO="${IMAGE%:*}"
    TAG="${IMAGE#*:}"

    # Step 1: Fetch the manifest digest
    DIGEST=$(curl -sI -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        "http://${REGISTRY}/v2/${REPO}/manifests/${TAG}" | \
        grep -i Docker-Content-Digest | awk '{print $2}' | tr -d $'\r')

    if [[ -z "$DIGEST" ]]; then
        echo "❌ Failed to find image: ${IMAGE}"
        return 1
    fi

    # Step 2: Delete the image by digest
    RESP=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
        "http://${REGISTRY}/v2/${REPO}/manifests/${DIGEST}")

    if [[ "$RESP" == "202" ]]; then
        echo "🗑️  Successfully removed ${IMAGE} (${DIGEST})"
    else
        echo "❌ Failed to remove ${IMAGE}"
        echo "HTTP status: $RESP"
    fi
}

case "$1" in
    images)
        list_images ;;
    tag)
        shift
        retag_image "$@" ;;
    pull)
        shift
        pull_image "$@" ;;
    push)
        shift
        push_image "$@" ;;
    rmi)
        shift
        remove_image "$@" ;;
    *)
        usage ;;
esac
